(() => {
  const $ = (id) => document.getElementById(id);
  let latestState = ElectionStore.getState();
  let builtPartySignature = '';
  let headlineTimer = null;
  let surpriseBusy = false;
  let autoExitRunning = false;

  function esc(value) {
    return String(value ?? '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));
  }

  function partyById(state, id) {
    return state.parties.find(p => p.id === id) || { id, name: id?.toUpperCase() || 'Unknown', short: id?.toUpperCase() || '?', color: '#8d96a4' };
  }

  function partyOptions(state, selected) {
    return state.parties.map(p => `<option value="${esc(p.id)}" ${p.id === selected ? 'selected' : ''}>${esc(p.short)} — ${esc(p.name)}</option>`).join('');
  }

  function resultTotals(state) {
    const totals = Object.fromEntries(state.parties.map(p => [p.id, 0]));
    Object.values(state.results).forEach(r => totals[r.partyId] = (totals[r.partyId] || 0) + 1);
    return totals;
  }

  function ensureExitRows(state) {
    const existing = new Map((state.exitPoll.rows || []).map(r => [r.partyId, Number(r.seats || 0)]));
    return state.parties.map(p => ({ partyId: p.id, seats: existing.get(p.id) || 0 }));
  }

  function setSurpriseMessage(message, tone = '') {
    const el = $('surpriseMessage');
    if (!el) return;
    el.textContent = message || '';
    el.className = `surprise-message${tone ? ` ${tone}` : ''}`;
  }

  function recomputeSurpriseWinnerDraft(state, allowHide = false) {
    if (!state.surprise?.enabled) return false;
    const totals = Object.fromEntries(state.parties.map(p => [p.id, 0]));
    Object.values(state.results || {}).forEach(r => { totals[r.partyId] = (totals[r.partyId] || 0) + 1; });
    const declared = Object.keys(state.results || {}).length;
    const remaining = Math.max(0, NEWH_DATA.TOTAL_SEATS - declared);
    const ranked = state.parties.map(p => ({ party: p, seats: totals[p.id] || 0 })).sort((a,b) => b.seats - a.seats);
    const leader = ranked[0];
    const second = ranked[1] || { seats: 0 };
    const guaranteed = Boolean(leader && declared > 0 && (leader.seats >= NEWH_DATA.MAJORITY || leader.seats > second.seats + remaining));

    if (guaranteed) {
      if (!state.winner.visible || state.winner.partyId !== leader.party.id) {
        state.winner.sequence = Number(state.winner.sequence || 0) + 1;
      }
      state.winner.visible = true;
      state.winner.partyId = leader.party.id;
      state.winner.seats = leader.seats;
      return true;
    }

    if (allowHide && state.winner.visible) {
      state.winner.visible = false;
      state.winner.seats = 0;
    }
    return false;
  }

  function renderSurprise(state) {
    const sp = state.surprise || {};
    const enabled = Boolean(sp.enabled && sp.planReady);
    const status = $('surpriseStatus');
    if (status) {
      status.className = 'status-pill';
      status.textContent = enabled ? 'OUTCOME LOCKED' : 'MANUAL MODE';
      if (enabled) status.classList.add('live');
    }
    if ($('surprisePlanStat')) $('surprisePlanStat').textContent = enabled ? '640 seats locked' : 'Not created';
    if ($('surpriseDeclaredStat')) $('surpriseDeclaredStat').textContent = `${Number(sp.declaredCount || Object.keys(state.results || {}).length)} / ${NEWH_DATA.TOTAL_SEATS}`;
    if ($('surpriseRemainingStat')) $('surpriseRemainingStat').textContent = String(Number.isFinite(Number(sp.remaining)) ? Number(sp.remaining) : Math.max(0, NEWH_DATA.TOTAL_SEATS - Object.keys(state.results || {}).length));
    if ($('surpriseExitStat')) $('surpriseExitStat').textContent = sp.exitPollRevealed ? 'REVEALED' : (enabled ? 'Locked until reveal' : 'Waiting');
    if ($('autoExitPoll22')) $('autoExitPoll22').checked = Boolean(sp.autoExitPoll22);
    if ($('createSurpriseBtn')) $('createSurpriseBtn').textContent = enabled ? 'Generate New Secret Election' : 'Generate Secret Election';
    if ($('surpriseExitPollBtn')) $('surpriseExitPollBtn').disabled = !enabled || surpriseBusy || Boolean(sp.exitPollRevealed);
    if ($('leaveSurpriseBtn')) $('leaveSurpriseBtn').disabled = !enabled || surpriseBusy;
    if ($('createSurpriseBtn')) $('createSurpriseBtn').disabled = surpriseBusy;

    document.body.classList.toggle('surprise-locked', enabled);
    document.querySelectorAll('[data-exit-party],[data-exit-seats]').forEach(el => { el.disabled = enabled; });
    if ($('exitCentrePartySelect')) $('exitCentrePartySelect').disabled = enabled;
    if ($('autoExitPoll')) $('autoExitPoll').disabled = enabled;
    if ($('exitPollToggle')) $('exitPollToggle').disabled = enabled && !sp.exitPollRevealed;
    if ($('winnerPartySelect')) $('winnerPartySelect').disabled = enabled;
    if ($('winnerSeatsInput')) $('winnerSeatsInput').disabled = enabled;
    if ($('winnerToggle')) $('winnerToggle').disabled = enabled && Number(state.winner.seats || 0) <= 0;
    if ($('clearResults')) $('clearResults').disabled = enabled;

    if (enabled) {
      const msg = sp.lastMessage || 'The hidden final result is locked in Supabase. Undeclared winners are not sent to this browser.';
      setSurpriseMessage(msg, sp.exitPollRevealed ? 'good' : 'warn');
    } else if (!surpriseBusy) {
      setSurpriseMessage('Connect Supabase, run the new SQL, then generate a secret election. The final winner and all undeclared seats stay hidden from the browser.');
    }
  }

  function renderExitEditor(state) {
    const rows = ensureExitRows(state);
    const centreSelect = $('exitCentrePartySelect');
    if (centreSelect) {
      centreSelect.innerHTML = `<option value="auto">Auto — party with most seats</option>` +
        state.parties.map(p => `<option value="${esc(p.id)}" ${state.exitPoll.centrePartyId === p.id ? 'selected' : ''}>${esc(p.short)} — ${esc(p.name)}</option>`).join('');
      centreSelect.value = state.exitPoll.centrePartyId || 'auto';
    }
    $('exitPollRows').innerHTML = rows.map((row, i) => {
      const p = partyById(state, row.partyId);
      return `<div class="exit-editor-row" data-exit-index="${i}">
        <div class="party-color-line" style="background:${p.color}"></div>
        <select data-exit-party="${i}">${partyOptions(state, row.partyId)}</select>
        <input data-exit-seats="${i}" type="number" min="0" max="640" value="${Number(row.seats || 0)}" aria-label="Seats for ${esc(p.name)}">
      </div>`;
    }).join('');
    const sum = rows.reduce((a,r) => a + Number(r.seats || 0), 0);
    $('exitPollSum').textContent = `${sum} / 640`;
    $('exitPollSum').style.color = sum === 640 ? '#67efa4' : '#ffbd68';
    $('exitPollToggle').textContent = state.exitPoll.visible ? 'Hide Exit Poll' : 'Announce Exit Poll';
  }

  function renderWinnerEditor(state) {
    if (document.activeElement !== $('winnerPartySelect')) $('winnerPartySelect').innerHTML = partyOptions(state, state.winner.partyId);
    if (document.activeElement !== $('winnerSeatsInput')) $('winnerSeatsInput').value = Number(state.winner.seats || 0);
    $('winnerToggle').textContent = state.winner.visible ? 'Hide Winner' : 'Announce Winner';
    const targetParty = partyById(state, state.winner.partyId);
    const declaredTotal = Object.values(state.results).filter(r => r.partyId === state.winner.partyId).length;
    const status = $('winnerSyncStatus');
    if (status) {
      if (state.surprise?.enabled) {
        status.innerHTML = state.winner.visible
          ? `<strong style="color:${targetParty.color}">${esc(targetParty.short)}</strong> has been mathematically called. The seat count continues updating as declarations arrive.`
          : `🔒 Surprise Mode: the winner is hidden. This panel will call the election automatically only when the declared results make the winner mathematically certain.`;
      } else {
        status.innerHTML = `<strong style="color:${targetParty.color}">${esc(targetParty.short)}</strong> currently has <strong>${declaredTotal}</strong> declared seat${declaredTotal === 1 ? '' : 's'}. Editing the target automatically adds or reassigns declarations.`;
      }
    }
  }

  function renderPartyAdmin(state) {
    const inUse = new Set([
      ...Object.values(state.results).map(r => r.partyId),
      ...Object.values(state.council.results || {}).map(r => r.partyId)
    ]);
    $('partyList').innerHTML = state.parties.map(p => `<div class="party-admin-item">
      <div class="party-admin-swatch" style="background:${p.color}"></div>
      <div class="party-admin-copy"><strong>${esc(p.name)}</strong><span>${esc(p.short)} • ${esc(p.id)}</span></div>
      <button class="icon-btn" data-delete-party="${esc(p.id)}" title="Delete party" ${inUse.has(p.id) ? 'disabled' : ''}>×</button>
    </div>`).join('');
  }

  function buildSeatGroups(state) {
    const container = $('regionSeatGroups');
    container.innerHTML = NEWH_DATA.regions.map((region, index) => {
      const seats = NEWH_DATA.constituencies.filter(s => s.regionId === region.id);
      const rows = seats.map(seat => {
        const current = state.results[seat.id];
        const selected = current?.partyId || seat.predictedWinner;
        const predicted = partyById(state, seat.predictedWinner);
        const previous = partyById(state, seat.previousWinner);
        return `<div class="seat-row" data-seat-row="${seat.id}" data-seat-region="${region.id}" data-seat-name="${esc(seat.name.toLowerCase())}">
          <div class="seat-row-copy"><strong>${esc(seat.name)}</strong><span>Prediction: ${esc(predicted.short)} ${seat.predictionConfidence}% • Previous: ${esc(previous.short)}</span></div>
          <select data-seat-select="${seat.id}">${partyOptions(state, selected)}</select>
          <button class="seat-declare-btn ${current ? 'declared' : ''}" data-declare-seat="${seat.id}">${current ? 'Change' : 'Declare'}</button>
        </div>`;
      }).join('');
      return `<details class="region-group" data-region-group="${region.id}" ${index === 0 ? 'open' : ''}><summary><span>${esc(region.name)}</span><span class="region-summary-meta" data-region-meta="${region.id}">0 / 40 declared</span></summary><div class="seat-list">${rows}</div></details>`;
    }).join('');
  }

  function updateSeatStatuses(state) {
    const secretMode = Boolean(state.surprise?.enabled && state.surprise?.planReady);
    NEWH_DATA.regions.forEach(region => {
      const count = NEWH_DATA.constituencies.filter(s => s.regionId === region.id && state.results[s.id]).length;
      const meta = document.querySelector(`[data-region-meta="${region.id}"]`);
      if (meta) meta.textContent = `${count} / 40 declared`;
    });
    NEWH_DATA.constituencies.forEach(seat => {
      const result = state.results[seat.id];
      const btn = document.querySelector(`[data-declare-seat="${seat.id}"]`);
      const select = document.querySelector(`[data-seat-select="${seat.id}"]`);
      if (btn) {
        btn.classList.toggle('declared', Boolean(result));
        btn.classList.toggle('secret', secretMode && !result);
        btn.textContent = secretMode ? (result ? 'Declared' : 'Reveal') : (result ? 'Change' : 'Declare');
        btn.disabled = secretMode && Boolean(result);
      }
      if (select) {
        select.disabled = secretMode;
        if (result && select.value !== result.partyId) select.value = result.partyId;
      }
    });
    if ($('declareNextPrediction')) $('declareNextPrediction').textContent = secretMode ? 'Reveal Random Declaration' : 'Random Next Declaration';
    if ($('undoResult')) $('undoResult').textContent = secretMode ? 'Undo Last Reveal' : 'Undo Last';
  }

  function applySeatFilter() {
    const query = $('seatSearch').value.trim().toLowerCase();
    const region = $('regionFilter').value;
    document.querySelectorAll('[data-seat-row]').forEach(row => {
      const matchesQuery = !query || row.dataset.seatName.includes(query);
      const matchesRegion = region === 'all' || row.dataset.seatRegion === region;
      row.hidden = !(matchesQuery && matchesRegion);
    });
    document.querySelectorAll('[data-region-group]').forEach(group => {
      const rows = [...group.querySelectorAll('[data-seat-row]')];
      const visible = rows.some(r => !r.hidden);
      group.hidden = !visible;
      if ((query || region !== 'all') && visible) group.open = true;
    });
  }

  function buildCouncilGroups(state) {
    $('councilGroups').innerHTML = NEWH_DATA.regions.map((region, index) => {
      const councils = NEWH_DATA.councils.filter(c => c.regionId === region.id);
      const rows = councils.map(c => {
        const current = state.council.results?.[c.id];
        const selected = current?.partyId || c.previousControl;
        const prev = partyById(state, c.previousControl);
        return `<div class="council-row" data-council-row="${c.id}" data-council-region="${region.id}" data-council-name="${esc(c.name.toLowerCase())}">
          <div class="council-row-copy"><strong>${esc(c.name)}</strong><span>${c.seats} councillors • Previous control: ${esc(prev.short)}</span></div>
          <select data-council-select="${c.id}">${partyOptions(state, selected)}</select>
          <button class="seat-declare-btn ${current ? 'declared' : ''}" data-declare-council="${c.id}">${current ? 'Change' : 'Declare'}</button>
        </div>`;
      }).join('');
      return `<details class="region-group" data-council-region-group="${region.id}" ${index === 0 ? 'open' : ''}><summary><span>${esc(region.name)}</span><span class="region-summary-meta" data-council-region-meta="${region.id}">0 / ${councils.length} declared</span></summary><div class="seat-list">${rows}</div></details>`;
    }).join('');
  }

  function updateCouncilStatuses(state) {
    NEWH_DATA.regions.forEach(region => {
      const all = NEWH_DATA.councils.filter(c => c.regionId === region.id);
      const count = all.filter(c => state.council.results?.[c.id]).length;
      const meta = document.querySelector(`[data-council-region-meta="${region.id}"]`);
      if (meta) meta.textContent = `${count} / ${all.length} declared`;
    });
    NEWH_DATA.councils.forEach(c => {
      const result = state.council.results?.[c.id];
      const btn = document.querySelector(`[data-declare-council="${c.id}"]`);
      const select = document.querySelector(`[data-council-select="${c.id}"]`);
      if (btn) {
        btn.classList.toggle('declared', Boolean(result));
        btn.textContent = result ? 'Change' : 'Declare';
      }
      if (select && result && select.value !== result.partyId) select.value = result.partyId;
    });
  }

  function applyCouncilFilter() {
    const query = $('councilSearch').value.trim().toLowerCase();
    const region = $('councilRegionFilter').value;
    document.querySelectorAll('[data-council-row]').forEach(row => {
      const matchesQuery = !query || row.dataset.councilName.includes(query);
      const matchesRegion = region === 'all' || row.dataset.councilRegion === region;
      row.hidden = !(matchesQuery && matchesRegion);
    });
    document.querySelectorAll('[data-council-region-group]').forEach(group => {
      const rows = [...group.querySelectorAll('[data-council-row]')];
      const visible = rows.some(r => !r.hidden);
      group.hidden = !visible;
      if ((query || region !== 'all') && visible) group.open = true;
    });
  }

  function renderCouncilTotalsEditor(state) {
    $('councilPartyTotals').innerHTML = state.parties.map(p => `<label class="council-party-total-row"><i class="bar" style="background:${p.color}"></i><strong>${esc(p.short)} councillor net change</strong><input type="number" data-council-party-total="${esc(p.id)}" value="${Number(state.council.partyTotals?.[p.id] || 0)}"></label>`).join('');
  }

  function renderMetrics(state) {
    const totals = resultTotals(state);
    const sorted = [...state.parties].sort((a,b) => (totals[b.id] || 0) - (totals[a.id] || 0));
    const leader = sorted[0];
    const declared = Object.keys(state.results).length;
    $('metricDeclared').textContent = `${declared} / 640`;
    $('metricLeader').textContent = declared && leader ? `${leader.short} ${totals[leader.id] || 0}` : '—';
    $('metricLeader').style.color = declared && leader ? leader.color : '';
    $('metricMode').textContent = state.mode === 'general' ? 'GENERAL' : 'COUNCILS';
  }

  function renderBroadcastControls(state) {
    if (document.activeElement !== $('yearSelect')) $('yearSelect').value = state.year;
    if (document.activeElement !== $('headlineInput')) $('headlineInput').value = state.broadcast.headline || '';
    if (document.activeElement !== $('strapInput')) $('strapInput').value = state.broadcast.strap || '';
    $('predictionsToggle').checked = Boolean(state.broadcast.showPredictions);
    $('tickerToggle').checked = Boolean(state.broadcast.showTicker);
    $('generalModeBtn').classList.toggle('active', state.mode === 'general');
    $('councilModeBtn').classList.toggle('active', state.mode === 'council');
  }

  function renderCloud() {
    const info = ElectionStore.getCloudInfo();
    const status = $('controlCloudStatus');
    status.className = 'status-pill';
    if (info.status === 'live') { status.textContent = 'LIVE SYNC'; status.classList.add('live'); }
    else if (info.status === 'connecting') status.textContent = 'CONNECTING';
    else if (info.status === 'error') { status.textContent = 'SYNC ERROR'; status.classList.add('error'); }
    else status.textContent = 'LOCAL';

    if (document.activeElement !== $('supabaseUrl')) $('supabaseUrl').value = info.config.url || '';
    if (document.activeElement !== $('supabaseKey')) $('supabaseKey').value = info.config.anonKey || '';
    $('cloudMessage').textContent = info.error ? info.error : (info.status === 'live' ? 'Connected. Other browsers will update in real time.' : 'Run supabase.sql once before connecting.');
  }

  function partySignature(state) {
    return state.parties.map(p => `${p.id}:${p.name}:${p.short}:${p.color}`).join('|');
  }

  function render(state) {
    latestState = state;
    renderMetrics(state);
    renderBroadcastControls(state);
    renderExitEditor(state);
    renderWinnerEditor(state);
    renderPartyAdmin(state);
    renderCouncilTotalsEditor(state);
    renderCloud();

    const sig = partySignature(state);
    if (sig !== builtPartySignature) {
      builtPartySignature = sig;
      buildSeatGroups(state);
      buildCouncilGroups(state);
      applySeatFilter();
      applyCouncilFilter();
    }
    updateSeatStatuses(state);
    updateCouncilStatuses(state);
    renderSurprise(state);
  }

  function commitExitRowsFromDom() {
    if (latestState.surprise?.enabled) return;
    const rows = [...document.querySelectorAll('[data-exit-index]')].map((row, i) => ({
      partyId: row.querySelector(`[data-exit-party="${i}"]`).value,
      seats: Math.max(0, Number(row.querySelector(`[data-exit-seats="${i}"]`).value || 0))
    }));
    ElectionStore.patch(s => { s.exitPoll.rows = rows; });
  }

  function applySeatDeclaration(seatId, partyId) {
    const seat = NEWH_DATA.constituencies.find(s => s.id === seatId);
    if (!seat) return;
    const prev = partyById(latestState, seat.previousWinner);
    const holdGain = partyId === seat.previousWinner ? 'HOLD' : `GAIN FROM ${prev.short}`;
    const now = Date.now();
    ElectionStore.patch(s => {
      s.results[seat.id] = { partyId, holdGain, timestamp: now };
      s.eventLog = s.eventLog.filter(e => e.seatId !== seat.id);
      s.eventLog.unshift({ seatId: seat.id, seatName: seat.name, region: seat.region, partyId, holdGain, timestamp: now });
      s.eventLog = s.eventLog.slice(0, 60);
    });
  }

  function shuffled(list) {
    const copy = [...list];
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }

  function applySeatResultToDraft(state, seat, partyId, timestamp = Date.now()) {
    const previous = state.parties.find(p => p.id === seat.previousWinner) || { short: String(seat.previousWinner || '').toUpperCase() };
    const holdGain = partyId === seat.previousWinner ? 'HOLD' : `GAIN FROM ${previous.short}`;
    state.results[seat.id] = { partyId, holdGain, timestamp };
    state.eventLog = state.eventLog.filter(e => e.seatId !== seat.id);
    state.eventLog.unshift({ seatId: seat.id, seatName: seat.name, region: seat.region, partyId, holdGain, timestamp });
  }

  function chooseReplacementParty(state, seat, excludedPartyId) {
    const valid = new Set(state.parties.map(p => p.id));
    const preferred = [seat.predictedWinner, seat.previousWinner].find(id => id !== excludedPartyId && valid.has(id));
    if (preferred) return preferred;
    const alternatives = state.parties.filter(p => p.id !== excludedPartyId);
    return alternatives.length ? alternatives[Math.floor(Math.random() * alternatives.length)].id : '';
  }

  function syncWinnerSeatTarget(partyId, rawTarget) {
    const target = Math.max(0, Math.min(NEWH_DATA.TOTAL_SEATS, Number(rawTarget || 0)));
    if (!partyId) return;

    ElectionStore.patch(state => {
      state.winner.partyId = partyId;
      state.winner.seats = target;

      let owned = NEWH_DATA.constituencies.filter(seat => state.results[seat.id]?.partyId === partyId);
      let current = owned.length;
      let stamp = Date.now();

      if (target > current) {
        let needed = target - current;
        const undeclared = shuffled(NEWH_DATA.constituencies.filter(seat => !state.results[seat.id]));
        for (const seat of undeclared) {
          if (needed <= 0) break;
          applySeatResultToDraft(state, seat, partyId, stamp++);
          needed--;
        }

        if (needed > 0) {
          const otherDeclared = shuffled(NEWH_DATA.constituencies.filter(seat => state.results[seat.id] && state.results[seat.id].partyId !== partyId));
          for (const seat of otherDeclared) {
            if (needed <= 0) break;
            applySeatResultToDraft(state, seat, partyId, stamp++);
            needed--;
          }
        }
      } else if (target < current) {
        const toReassign = shuffled(owned).slice(0, current - target);
        for (const seat of toReassign) {
          const replacement = chooseReplacementParty(state, seat, partyId);
          if (replacement) {
            applySeatResultToDraft(state, seat, replacement, stamp++);
          } else {
            delete state.results[seat.id];
            state.eventLog = state.eventLog.filter(e => e.seatId !== seat.id);
          }
        }
      }

      state.eventLog = state.eventLog
        .sort((a, b) => Number(b.timestamp || 0) - Number(a.timestamp || 0))
        .slice(0, 60);
    });
  }

  function randomWinnerForSeat(seat) {
    const partyIds = latestState.parties.map(p => p.id);
    const predictedValid = partyIds.includes(seat.predictedWinner);
    const previousValid = partyIds.includes(seat.previousWinner);
    const roll = Math.random();
    if (predictedValid && roll < .74) return seat.predictedWinner;
    if (previousValid && seat.previousWinner !== seat.predictedWinner && roll < .88) return seat.previousWinner;
    if (!partyIds.length) return '';
    return partyIds[Math.floor(Math.random() * partyIds.length)];
  }

  async function runSurpriseRpc(name, args = {}) {
    if (surpriseBusy) return null;
    surpriseBusy = true;
    renderSurprise(ElectionStore.getState());
    try {
      const data = await ElectionStore.rpc(name, args);
      return data;
    } catch (err) {
      console.error(err);
      setSurpriseMessage(err?.message || String(err), 'warn');
      alert(err?.message || String(err));
      return null;
    } finally {
      surpriseBusy = false;
      renderSurprise(ElectionStore.getState());
    }
  }

  async function generateSecretElection() {
    if (!ElectionStore.getCloudInfo().configured) {
      alert('Connect Supabase first, then run the new supabase.sql file.');
      return;
    }
    if (Object.keys(latestState.results || {}).length && !confirm('Generate a brand-new hidden election? This clears the current 640-seat results and creates a completely new secret winner.')) return;
    setSurpriseMessage('Generating and locking 640 secret constituency results…', 'warn');
    const data = await runSurpriseRpc('newh_create_surprise_election', { p_year: latestState.year || '2026' });
    if (!data?.ok) return;
    ElectionStore.patch(state => {
      state.results = {};
      state.eventLog = [];
      state.exitPoll.visible = false;
      state.exitPoll.rows = state.parties.map(p => ({ partyId: p.id, seats: 0 }));
      state.exitPoll.centrePartyId = 'auto';
      state.winner.visible = false;
      state.winner.seats = 0;
      state.surprise = {
        ...(state.surprise || {}),
        enabled: true,
        planReady: true,
        exitPollRevealed: false,
        declaredCount: 0,
        remaining: NEWH_DATA.TOTAL_SEATS,
        lastMessage: data.message || 'Secret election generated. The actual winner is hidden.'
      };
    });
  }

  async function revealSurpriseExitPoll() {
    const state = ElectionStore.getState();
    if (!state.surprise?.enabled || !state.surprise?.planReady || state.surprise?.exitPollRevealed) return;
    if (autoExitRunning) return;
    autoExitRunning = true;
    try {
      setSurpriseMessage('Revealing the locked 22:00 exit poll…', 'warn');
      const data = await runSurpriseRpc('newh_reveal_exit_poll');
      if (!data?.ok) return;
      ElectionStore.patch(s => {
        s.exitPoll.title = data.title || 'EXIT POLL';
        s.exitPoll.rows = Array.isArray(data.rows) ? data.rows : s.exitPoll.rows;
        s.exitPoll.centrePartyId = data.leaderPartyId || 'auto';
        s.exitPoll.visible = true;
        s.exitPoll.sequence = Number(s.exitPoll.sequence || 0) + 1;
        s.surprise.exitPollRevealed = true;
        s.surprise.lastMessage = data.message || 'Exit poll revealed. The actual final winner remains secret.';
      });
    } finally {
      autoExitRunning = false;
    }
  }

  async function revealSecretDeclaration(seatId = null) {
    const state = ElectionStore.getState();
    if (!state.surprise?.enabled || !state.surprise?.planReady) return;
    const data = await runSurpriseRpc('newh_reveal_declaration', { p_seat_id: seatId || null });
    if (!data?.ok) return;
    const seat = NEWH_DATA.constituencies.find(x => x.id === data.seatId);
    if (!seat) return alert(`Supabase returned unknown constituency ${data.seatId}.`);
    const stamp = Date.now();
    ElectionStore.patch(s => {
      applySeatResultToDraft(s, seat, data.partyId, stamp);
      s.eventLog = s.eventLog.slice(0, 60);
      s.surprise.declaredCount = Number(data.declaredCount || Object.keys(s.results).length);
      s.surprise.remaining = Number(data.remaining ?? (NEWH_DATA.TOTAL_SEATS - Object.keys(s.results).length));
      s.surprise.lastMessage = `${seat.name} declared. ${s.surprise.remaining} constituency result${s.surprise.remaining === 1 ? '' : 's'} still hidden.`;
      recomputeSurpriseWinnerDraft(s, false);
    });
  }

  async function undoSecretDeclaration() {
    const data = await runSurpriseRpc('newh_undo_last_declaration');
    if (!data?.ok) return;
    ElectionStore.patch(s => {
      delete s.results[data.seatId];
      s.eventLog = s.eventLog.filter(e => e.seatId !== data.seatId);
      s.surprise.declaredCount = Math.max(0, Number(data.declaredCount || 0));
      s.surprise.remaining = Math.max(0, Number(data.remaining ?? (NEWH_DATA.TOTAL_SEATS - s.surprise.declaredCount)));
      s.surprise.lastMessage = 'Last surprise declaration returned to the hidden pool.';
      recomputeSurpriseWinnerDraft(s, true);
    });
  }

  function updateSurpriseClock() {
    const el = $('surpriseClock');
    const now = new Date();
    if (el) el.textContent = `Local time ${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}:${String(now.getSeconds()).padStart(2,'0')}`;
    const state = ElectionStore.getState();
    if (state.surprise?.enabled && state.surprise?.planReady && state.surprise?.autoExitPoll22 && !state.surprise?.exitPollRevealed && now.getHours() >= 22) {
      revealSurpriseExitPoll();
    }
  }

  function declareCouncil(councilId, partyId) {
    const council = NEWH_DATA.councils.find(c => c.id === councilId);
    if (!council) return;
    const prev = partyById(latestState, council.previousControl);
    const change = partyId === council.previousControl ? 'HOLD' : `GAIN FROM ${prev.short}`;
    const now = Date.now();
    ElectionStore.patch(s => {
      s.council.results[council.id] = { partyId, change, timestamp: now };
      s.council.eventLog = s.council.eventLog.filter(e => e.councilId !== council.id);
      s.council.eventLog.unshift({ councilId: council.id, councilName: council.name, region: council.region, partyId, change, timestamp: now });
      s.council.eventLog = s.council.eventLog.slice(0, 60);
    });
  }

  // Initial filter option lists.
  const regionOptions = NEWH_DATA.regions.map(r => `<option value="${r.id}">${esc(r.name)}</option>`).join('');
  $('regionFilter').insertAdjacentHTML('beforeend', regionOptions);
  $('councilRegionFilter').insertAdjacentHTML('beforeend', regionOptions);

  // Top-level controls.
  document.querySelectorAll('[data-mode]').forEach(btn => btn.addEventListener('click', () => ElectionStore.patch(s => { s.mode = btn.dataset.mode; })));
  $('yearSelect').addEventListener('change', e => ElectionStore.patch(s => { s.year = e.target.value; }));
  $('headlineInput').addEventListener('input', e => {
    clearTimeout(headlineTimer);
    const value = e.target.value;
    headlineTimer = setTimeout(() => ElectionStore.patch(s => { s.broadcast.headline = value; }), 180);
  });
  $('strapInput').addEventListener('input', e => {
    clearTimeout(headlineTimer);
    const value = e.target.value;
    headlineTimer = setTimeout(() => ElectionStore.patch(s => { s.broadcast.strap = value; }), 180);
  });
  $('predictionsToggle').addEventListener('change', e => ElectionStore.patch(s => { s.broadcast.showPredictions = e.target.checked; }));
  $('tickerToggle').addEventListener('change', e => ElectionStore.patch(s => { s.broadcast.showTicker = e.target.checked; }));

  $('exitPollRows').addEventListener('change', commitExitRowsFromDom);
  $('exitCentrePartySelect').addEventListener('change', e => {
    if (latestState.surprise?.enabled) return;
    ElectionStore.patch(s => { s.exitPoll.centrePartyId = e.target.value || 'auto'; });
  });
  $('exitPollToggle').addEventListener('click', () => {
    if (latestState.surprise?.enabled && !latestState.surprise?.exitPollRevealed) return;
    commitExitRowsFromDom();
    ElectionStore.patch(s => {
      const nextVisible = !s.exitPoll.visible;
      s.exitPoll.visible = nextVisible;
      if (nextVisible) s.exitPoll.sequence = Number(s.exitPoll.sequence || 0) + 1;
    });
  });
  $('autoExitPoll').addEventListener('click', () => {
    if (latestState.surprise?.enabled) return;
    const parties = latestState.parties;
    if (!parties.length) return;
    const weights = parties.map((_, i) => Math.max(.025, (1 / (i + 1)) * (.78 + Math.random() * .42)));
    const totalW = weights.reduce((a,b) => a+b,0);
    let allocated = 0;
    const rows = parties.map((p,i) => {
      const seats = Math.floor(weights[i] / totalW * NEWH_DATA.TOTAL_SEATS);
      allocated += seats;
      return { partyId: p.id, seats };
    });
    let remainder = NEWH_DATA.TOTAL_SEATS - allocated;
    let i = 0;
    while (remainder-- > 0) rows[i++ % rows.length].seats += 1;
    rows.sort((a,b) => b.seats - a.seats);
    ElectionStore.patch(s => { s.exitPoll.rows = rows; });
  });

  $('winnerPartySelect').addEventListener('change', e => { if (!latestState.surprise?.enabled) ElectionStore.patch(s => { s.winner.partyId = e.target.value; }); });
  $('winnerSeatsInput').addEventListener('change', e => {
    if (latestState.surprise?.enabled) return;
    syncWinnerSeatTarget($('winnerPartySelect').value, e.target.value);
  });
  $('winnerToggle').addEventListener('click', () => {
    if (latestState.surprise?.enabled) {
      if (Number(latestState.winner.seats || 0) <= 0) return;
      ElectionStore.patch(s => {
        const nextVisible = !s.winner.visible;
        s.winner.visible = nextVisible;
        if (nextVisible) s.winner.sequence = Number(s.winner.sequence || 0) + 1;
      });
      return;
    }
    const partyId = $('winnerPartySelect').value;
    const seatTarget = Math.max(0, Math.min(NEWH_DATA.TOTAL_SEATS, Number($('winnerSeatsInput').value || 0)));
    syncWinnerSeatTarget(partyId, seatTarget);
    ElectionStore.patch(s => {
      s.winner.partyId = partyId;
      s.winner.seats = seatTarget;
      const nextVisible = !s.winner.visible;
      s.winner.visible = nextVisible;
      if (nextVisible) s.winner.sequence = Number(s.winner.sequence || 0) + 1;
    });
  });

  $('addPartyBtn').addEventListener('click', () => {
    const name = $('newPartyName').value.trim();
    const short = $('newPartyShort').value.trim().toUpperCase();
    const color = $('newPartyColor').value;
    if (!name || !short) return alert('Enter both a party name and short code.');
    let base = name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,18) || 'party';
    let id = base, n = 2;
    while (latestState.parties.some(p => p.id === id)) id = `${base}-${n++}`;
    ElectionStore.patch(s => {
      s.parties.push({ id, name, short: short.slice(0,5), color });
      s.exitPoll.rows.push({ partyId: id, seats: 0 });
    });
    $('newPartyName').value = '';
    $('newPartyShort').value = '';
  });

  $('partyList').addEventListener('click', e => {
    const btn = e.target.closest('[data-delete-party]');
    if (!btn) return;
    const id = btn.dataset.deleteParty;
    const used = Object.values(latestState.results).some(r => r.partyId === id) || Object.values(latestState.council.results || {}).some(r => r.partyId === id);
    if (used) return alert('That party already has declared results. Clear or change those results first.');
    if (latestState.parties.length <= 1) return alert('Keep at least one party.');
    if (!confirm(`Delete ${partyById(latestState,id).name}?`)) return;
    ElectionStore.patch(s => {
      s.parties = s.parties.filter(p => p.id !== id);
      s.exitPoll.rows = s.exitPoll.rows.filter(r => r.partyId !== id);
      delete s.council.partyTotals[id];
      if (s.winner.partyId === id) s.winner.partyId = s.parties[0]?.id || '';
    });
  });

  // Constituencies.
  $('regionSeatGroups').addEventListener('click', async e => {
    const btn = e.target.closest('[data-declare-seat]');
    if (!btn) return;
    const seatId = btn.dataset.declareSeat;
    if (latestState.surprise?.enabled) {
      await revealSecretDeclaration(seatId);
      return;
    }
    const select = document.querySelector(`[data-seat-select="${seatId}"]`);
    applySeatDeclaration(seatId, select.value);
  });
  $('seatSearch').addEventListener('input', applySeatFilter);
  $('regionFilter').addEventListener('change', applySeatFilter);
  $('declareNextPrediction').addEventListener('click', async () => {
    if (latestState.surprise?.enabled) {
      await revealSecretDeclaration(null);
      return;
    }
    const undeclared = NEWH_DATA.constituencies.filter(seat => !latestState.results[seat.id]);
    if (!undeclared.length) return alert('All 640 seats are already declared.');
    const seat = undeclared[Math.floor(Math.random() * undeclared.length)];
    const partyId = randomWinnerForSeat(seat);
    if (!partyId) return;
    applySeatDeclaration(seat.id, partyId);
  });
  $('undoResult').addEventListener('click', async () => {
    if (latestState.surprise?.enabled) {
      await undoSecretDeclaration();
      return;
    }
    const last = latestState.eventLog[0];
    if (!last) return;
    ElectionStore.patch(s => {
      delete s.results[last.seatId];
      s.eventLog = s.eventLog.slice(1);
    });
  });
  $('clearResults').addEventListener('click', () => {
    if (latestState.surprise?.enabled) return alert('Surprise Mode is locked. Use “Generate New Secret Election” to reset all 640 hidden results.');
    if (!confirm('Clear all 640 constituency results and the declaration log?')) return;
    ElectionStore.patch(s => { s.results = {}; s.eventLog = []; s.winner.visible = false; });
  });

  // Secret surprise election engine.
  $('createSurpriseBtn').addEventListener('click', generateSecretElection);
  $('surpriseExitPollBtn').addEventListener('click', revealSurpriseExitPoll);
  $('autoExitPoll22').addEventListener('change', e => ElectionStore.patch(s => {
    s.surprise.autoExitPoll22 = Boolean(e.target.checked);
    s.surprise.lastMessage = e.target.checked
      ? '22:00 automatic exit poll is armed on this control-room browser.'
      : '22:00 automatic exit poll is not armed. You can still reveal it manually.';
  }));
  $('leaveSurpriseBtn').addEventListener('click', () => {
    if (!confirm('Return to manual election mode? The hidden Supabase plan will stop controlling declarations.')) return;
    ElectionStore.patch(s => {
      s.surprise.enabled = false;
      s.surprise.planReady = false;
      s.surprise.lastMessage = 'Manual election mode';
      s.exitPoll.visible = false;
      s.winner.visible = false;
    });
  });

  // Councils.
  $('councilPartyTotals').addEventListener('change', e => {
    const input = e.target.closest('[data-council-party-total]');
    if (!input) return;
    const id = input.dataset.councilPartyTotal;
    ElectionStore.patch(s => { s.council.partyTotals[id] = Number(input.value || 0); });
  });
  $('councilGroups').addEventListener('click', e => {
    const btn = e.target.closest('[data-declare-council]');
    if (!btn) return;
    const id = btn.dataset.declareCouncil;
    const select = document.querySelector(`[data-council-select="${id}"]`);
    declareCouncil(id, select.value);
  });
  $('councilSearch').addEventListener('input', applyCouncilFilter);
  $('councilRegionFilter').addEventListener('change', applyCouncilFilter);
  $('clearCouncils').addEventListener('click', () => {
    if (!confirm('Clear all council control results and council logs?')) return;
    ElectionStore.patch(s => { s.council.results = {}; s.council.eventLog = []; });
  });

  // Cloud.
  $('saveCloud').addEventListener('click', async () => {
    ElectionStore.saveCloudConfig($('supabaseUrl').value, $('supabaseKey').value);
    await ElectionStore.connectCloud();
    renderCloud();
  });
  $('disconnectCloud').addEventListener('click', () => {
    ElectionStore.disconnectCloud();
    renderCloud();
  });

  $('resetAll').addEventListener('click', () => {
    if (!confirm('Reset the whole election state? This cannot be undone.')) return;
    const cloud = ElectionStore.readCloudConfig();
    ElectionStore.reset();
    if (cloud.url && cloud.anonKey) ElectionStore.connectCloud();
  });

  updateSurpriseClock();
  setInterval(updateSurpriseClock, 1000);
  ElectionStore.subscribe(render);
})();
