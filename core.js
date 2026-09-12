// Shared state + live sync engine for the control room and presentation.

window.ElectionStore = (() => {
  const STORAGE_KEY = 'newh-election-state-v1';
  const CONFIG_KEY = 'newh-election-cloud-v1';
  const CHANNEL_NAME = 'newh-election-live-v1';
  const ROW_ID = 'newh-live';
  const TABLE = 'live_state';

  const channel = 'BroadcastChannel' in window ? new BroadcastChannel(CHANNEL_NAME) : null;
  const listeners = new Set();
  let cloudClient = null;
  let cloudSubscription = null;
  let cloudPushTimer = null;
  let cloudStatus = 'local';
  let lastCloudError = '';

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function defaultExitRows() {
    return NEWH_DATA.defaultParties.slice(0, 6).map((p, index) => ({
      partyId: p.id,
      seats: [121, 410, 61, 13, 22, 13][index] ?? 0
    }));
  }

  function makeDefaultState() {
    return {
      version: 1,
      mode: 'general',
      year: '2026',
      updatedAt: Date.now(),
      parties: clone(NEWH_DATA.defaultParties),
      results: {},
      eventLog: [],
      exitPoll: {
        visible: false,
        sequence: 0,
        title: 'EXIT POLL',
        centrePartyId: 'auto',
        rows: defaultExitRows()
      },
      winner: {
        visible: false,
        sequence: 0,
        partyId: 'lab',
        seats: 0
      },
      broadcast: {
        headline: 'NEW H DECIDES',
        strap: 'Live election results and projections',
        showPredictions: true,
        showTicker: true
      },
      council: {
        partyTotals: {},
        results: {},
        eventLog: []
      }
    };
  }

  function normalize(raw) {
    const base = makeDefaultState();
    if (!raw || typeof raw !== 'object') return base;
    const state = {
      ...base,
      ...raw,
      exitPoll: { ...base.exitPoll, ...(raw.exitPoll || {}) },
      winner: { ...base.winner, ...(raw.winner || {}) },
      broadcast: { ...base.broadcast, ...(raw.broadcast || {}) },
      council: { ...base.council, ...(raw.council || {}) }
    };
    if (!Array.isArray(state.parties) || !state.parties.length) state.parties = clone(base.parties);
    if (!state.results || typeof state.results !== 'object') state.results = {};
    if (!Array.isArray(state.eventLog)) state.eventLog = [];
    if (!Array.isArray(state.exitPoll.rows)) state.exitPoll.rows = defaultExitRows();
    if (!state.council.results || typeof state.council.results !== 'object') state.council.results = {};
    if (!state.council.partyTotals || typeof state.council.partyTotals !== 'object') state.council.partyTotals = {};
    if (!Array.isArray(state.council.eventLog)) state.council.eventLog = [];
    return state;
  }

  function loadLocal() {
    try {
      return normalize(JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null'));
    } catch (_) {
      return makeDefaultState();
    }
  }

  let state = loadLocal();

  function notify(source = 'local') {
    const snapshot = clone(state);
    listeners.forEach((fn) => {
      try { fn(snapshot, source); } catch (err) { console.error(err); }
    });
    window.dispatchEvent(new CustomEvent('election-state', { detail: { state: snapshot, source } }));
  }

  function saveLocal() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (_) {}
  }

  function broadcastLocal() {
    if (channel) channel.postMessage({ type: 'state', state });
  }

  function setState(next, options = {}) {
    state = normalize(typeof next === 'function' ? next(clone(state)) : next);
    if (!options.keepTimestamp) state.updatedAt = Date.now();
    saveLocal();
    notify(options.source || 'local');
    if (!options.remote) {
      broadcastLocal();
      queueCloudPush();
    }
    return clone(state);
  }

  function patch(mutator, options = {}) {
    const draft = clone(state);
    mutator(draft);
    return setState(draft, options);
  }

  function getState() { return clone(state); }
  function reset() { return setState(makeDefaultState()); }

  function subscribe(fn) {
    listeners.add(fn);
    fn(clone(state), 'initial');
    return () => listeners.delete(fn);
  }

  if (channel) {
    channel.onmessage = (event) => {
      if (event.data?.type === 'state' && event.data.state) {
        const incoming = normalize(event.data.state);
        if ((incoming.updatedAt || 0) >= (state.updatedAt || 0)) {
          state = incoming;
          saveLocal();
          notify('tab');
        }
      }
    };
  }

  window.addEventListener('storage', (event) => {
    if (event.key === CONFIG_KEY) {
      if (cloudConfigured()) connectCloud();
      else disconnectCloud();
      return;
    }
    if (event.key !== STORAGE_KEY || !event.newValue) return;
    try {
      const incoming = normalize(JSON.parse(event.newValue));
      if ((incoming.updatedAt || 0) >= (state.updatedAt || 0)) {
        state = incoming;
        notify('storage');
      }
    } catch (_) {}
  });

  function readCloudConfig() {
    try {
      const parsed = JSON.parse(localStorage.getItem(CONFIG_KEY) || '{}');
      return { url: parsed.url || '', anonKey: parsed.anonKey || '' };
    } catch (_) {
      return { url: '', anonKey: '' };
    }
  }

  function saveCloudConfig(url, anonKey) {
    localStorage.setItem(CONFIG_KEY, JSON.stringify({ url: (url || '').trim(), anonKey: (anonKey || '').trim() }));
  }

  function cloudConfigured() {
    const cfg = readCloudConfig();
    return Boolean(cfg.url && cfg.anonKey);
  }

  async function connectCloud() {
    const cfg = readCloudConfig();
    if (!cfg.url || !cfg.anonKey) {
      cloudStatus = 'local';
      lastCloudError = '';
      notify('cloud-status');
      return false;
    }
    if (!window.supabase?.createClient) {
      cloudStatus = 'error';
      lastCloudError = 'Supabase client library did not load.';
      notify('cloud-status');
      return false;
    }

    try {
      cloudStatus = 'connecting';
      lastCloudError = '';
      notify('cloud-status');
      cloudClient = window.supabase.createClient(cfg.url, cfg.anonKey, {
        realtime: { params: { eventsPerSecond: 10 } }
      });

      const { data, error } = await cloudClient.from(TABLE).select('state, updated_at').eq('id', ROW_ID).maybeSingle();
      if (error) throw error;

      if (data?.state) {
        const cloudTimestamp = Number(data.state?.updatedAt || 0);
        if (cloudTimestamp > 0 && cloudTimestamp >= (state.updatedAt || 0)) {
          const incoming = normalize(data.state);
          state = incoming;
          saveLocal();
          notify('cloud-load');
        } else {
          await pushCloudNow();
        }
      } else {
        const { error: insertError } = await cloudClient.from(TABLE).upsert({ id: ROW_ID, state, updated_at: new Date().toISOString() });
        if (insertError) throw insertError;
      }

      if (cloudSubscription) {
        try { await cloudClient.removeChannel(cloudSubscription); } catch (_) {}
      }

      cloudSubscription = cloudClient
        .channel('newh-election-state')
        .on('postgres_changes', { event: '*', schema: 'public', table: TABLE, filter: `id=eq.${ROW_ID}` }, (payload) => {
          const incomingRaw = payload.new?.state;
          if (!incomingRaw || !incomingRaw.updatedAt) return;
          const incoming = normalize(incomingRaw);
          if ((incoming.updatedAt || 0) > (state.updatedAt || 0)) {
            state = incoming;
            saveLocal();
            broadcastLocal();
            notify('cloud');
          }
        })
        .subscribe((status) => {
          if (status === 'SUBSCRIBED') {
            cloudStatus = 'live';
            lastCloudError = '';
            notify('cloud-status');
          }
        });
      return true;
    } catch (err) {
      console.error(err);
      cloudStatus = 'error';
      lastCloudError = err?.message || String(err);
      notify('cloud-status');
      return false;
    }
  }

  async function pushCloudNow() {
    if (!cloudClient) return false;
    try {
      const { error } = await cloudClient.from(TABLE).upsert({
        id: ROW_ID,
        state,
        updated_at: new Date().toISOString()
      });
      if (error) throw error;
      return true;
    } catch (err) {
      cloudStatus = 'error';
      lastCloudError = err?.message || String(err);
      notify('cloud-status');
      return false;
    }
  }

  function queueCloudPush() {
    if (!cloudClient) return;
    clearTimeout(cloudPushTimer);
    cloudPushTimer = setTimeout(pushCloudNow, 120);
  }

  function disconnectCloud() {
    if (cloudClient && cloudSubscription) {
      try { cloudClient.removeChannel(cloudSubscription); } catch (_) {}
    }
    cloudSubscription = null;
    cloudClient = null;
    cloudStatus = 'local';
    lastCloudError = '';
    notify('cloud-status');
  }

  function getCloudInfo() {
    return {
      configured: cloudConfigured(),
      status: cloudStatus,
      error: lastCloudError,
      config: readCloudConfig()
    };
  }

  // Attempt cloud automatically when configured.
  setTimeout(() => { if (cloudConfigured()) connectCloud(); }, 0);

  return {
    getState,
    setState,
    patch,
    reset,
    subscribe,
    makeDefaultState,
    readCloudConfig,
    saveCloudConfig,
    connectCloud,
    disconnectCloud,
    getCloudInfo,
    STORAGE_KEY
  };
})();
