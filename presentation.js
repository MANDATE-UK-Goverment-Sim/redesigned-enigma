(() => {
  const $ = (id) => document.getElementById(id);
  const svgNS = 'http://www.w3.org/2000/svg';
  const seatEls = new Map();
  const seatPositions = new Map();
  let previousExitSequence = -1;
  let previousWinnerSequence = -1;

  // 24 rows, deliberately tapered and offset to form a fictional island/country.
  // Total cells = 640, so every constituency appears on the map.
  const MAP_ROWS = [12,16,20,24,28,30,32,34,36,37,37,36,36,34,32,30,28,26,24,22,20,18,16,12];
  const MAP_OFFSETS = [-98,-82,-62,-38,-12,12,38,58,70,54,32,8,-18,-48,-68,-78,-62,-44,-20,6,28,42,24,-4];

  function partyById(state, id) {
    return state.parties.find(p => p.id === id) || { id, name: id?.toUpperCase() || 'Unknown', short: id?.toUpperCase() || '?', color: '#8c95a3' };
  }

  function hexPoints(cx, cy, r) {
    const pts = [];
    for (let i = 0; i < 6; i++) {
      const angle = Math.PI / 180 * (60 * i - 30);
      pts.push(`${(cx + r * Math.cos(angle)).toFixed(2)},${(cy + r * Math.sin(angle)).toFixed(2)}`);
    }
    return pts.join(' ');
  }

  function buildCountryOutline(rowBounds) {
    if (!rowBounds.length) return '';
    const left = rowBounds.map(r => [r.left, r.cy]);
    const right = [...rowBounds].reverse().map(r => [r.right, r.cy]);
    const top = [(rowBounds[0].left + rowBounds[0].right) / 2, rowBounds[0].cy - 30];
    const bottomRow = rowBounds[rowBounds.length - 1];
    const bottom = [(bottomRow.left + bottomRow.right) / 2, bottomRow.cy + 32];
    const pts = [top, ...left, bottom, ...right];
    return `M ${pts.map((p, i) => `${i ? 'L' : ''} ${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ')} Z`;
  }

  function buildMap(state) {
    const svg = $('constituencyMap');
    svg.innerHTML = '';
    seatEls.clear();
    seatPositions.clear();

    const defs = document.createElementNS(svgNS, 'defs');
    defs.innerHTML = `
      <linearGradient id="countryFill" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#18283a" stop-opacity=".9"/>
        <stop offset="55%" stop-color="#0e1825" stop-opacity=".84"/>
        <stop offset="100%" stop-color="#192130" stop-opacity=".88"/>
      </linearGradient>
      <filter id="countryGlow" x="-30%" y="-30%" width="160%" height="160%">
        <feGaussianBlur stdDeviation="10" result="blur"/>
        <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>`;
    svg.appendChild(defs);

    const rowBounds = [];
    const r = 13.4;
    const xStep = 30.0;
    const yStep = 30.8;
    const mapCenter = 770;
    const startY = 106;
    let seatIndex = 0;

    MAP_ROWS.forEach((count, row) => {
      const cy = startY + row * yStep;
      const centerX = mapCenter + MAP_OFFSETS[row];
      const rowWidth = (count - 1) * xStep;
      const startX = centerX - rowWidth / 2;
      rowBounds.push({ left: startX - r * 1.3, right: startX + rowWidth + r * 1.3, cy });

      for (let col = 0; col < count; col++) {
        const seat = NEWH_DATA.constituencies[seatIndex++];
        if (!seat) continue;
        const coastalNudge = Math.sin((row + col * .72) * .63) * 2.4;
        const cx = startX + col * xStep + coastalNudge;
        seatPositions.set(seat.id, { cx, cy });
      }
    });

    const outlinePath = buildCountryOutline(rowBounds);
    const coastGlow = document.createElementNS(svgNS, 'path');
    coastGlow.setAttribute('d', outlinePath);
    coastGlow.setAttribute('class', 'country-coast country-coast-glow');
    coastGlow.setAttribute('filter', 'url(#countryGlow)');
    svg.appendChild(coastGlow);

    const coast = document.createElementNS(svgNS, 'path');
    coast.setAttribute('d', outlinePath);
    coast.setAttribute('class', 'country-coast');
    coast.setAttribute('fill', 'url(#countryFill)');
    svg.appendChild(coast);

    // Decorative inland contour strokes help the silhouette read as a country,
    // rather than a plain rectangular cartogram.
    [6, 11, 16].forEach(row => {
      const b = rowBounds[row];
      const line = document.createElementNS(svgNS, 'path');
      const mid = (b.left + b.right) / 2;
      line.setAttribute('d', `M ${b.left + 28} ${b.cy - 5} Q ${mid} ${b.cy + 24} ${b.right - 22} ${b.cy - 4}`);
      line.setAttribute('class', 'country-contour');
      svg.appendChild(line);
    });

    NEWH_DATA.constituencies.forEach((seat) => {
      const pos = seatPositions.get(seat.id);
      if (!pos) return;
      const poly = document.createElementNS(svgNS, 'polygon');
      poly.setAttribute('points', hexPoints(pos.cx, pos.cy, r));
      poly.setAttribute('class', 'map-seat');
      poly.dataset.seatId = seat.id;
      const title = document.createElementNS(svgNS, 'title');
      title.textContent = seat.name;
      poly.appendChild(title);
      svg.appendChild(poly);
      seatEls.set(seat.id, poly);
    });

    updateMap(state);
  }

  function updateMap(state) {
    NEWH_DATA.constituencies.forEach((seat) => {
      const el = seatEls.get(seat.id);
      if (!el) return;
      const result = state.results[seat.id];
      const predictedParty = partyById(state, seat.predictedWinner);
      const winner = result ? partyById(state, result.partyId) : predictedParty;
      el.style.fill = winner.color;
      el.style.opacity = result ? '1' : (state.broadcast.showPredictions ? '.28' : '.085');
      el.classList.toggle('declared-seat', Boolean(result));
      const title = el.querySelector('title');
      if (title) {
        title.textContent = result
          ? `${seat.name} — ${winner.name} ${result.holdGain || ''}. Pre-election prediction: ${predictedParty.name} ${seat.predictionConfidence}%`
          : `${seat.name} — prediction: ${predictedParty.name} (${seat.predictionConfidence}%)`;
      }
    });
  }

  function resultsTotals(state) {
    const totals = Object.fromEntries(state.parties.map(p => [p.id, 0]));
    Object.values(state.results).forEach((result) => {
      totals[result.partyId] = (totals[result.partyId] || 0) + 1;
    });
    return totals;
  }

  function projectedTotals(state) {
    const totals = Object.fromEntries(state.parties.map(p => [p.id, 0]));
    NEWH_DATA.constituencies.forEach((seat) => {
      const result = state.results[seat.id];
      let id = result?.partyId || seat.predictedWinner;
      if (!state.parties.some(p => p.id === id)) id = state.parties[0]?.id;
      if (id) totals[id] = (totals[id] || 0) + 1;
    });
    return totals;
  }

  function renderLegend(state) {
    $('mapLegend').innerHTML = state.parties.slice(0, 8).map(p => `<span class="legend-item"><i class="legend-dot" style="background:${p.color}"></i>${escapeHtml(p.short)}</span>`).join('');
  }

  function renderTotals(state) {
    const totals = resultsTotals(state);
    const declared = Object.keys(state.results).length;
    const sorted = [...state.parties].sort((a,b) => (totals[b.id] || 0) - (totals[a.id] || 0));
    const maxScale = Math.max(NEWH_DATA.MAJORITY, ...Object.values(totals), 1);
    $('seatTotals').innerHTML = sorted.map(p => {
      const value = totals[p.id] || 0;
      const width = Math.min(100, value / maxScale * 100);
      return `<div class="total-row">
        <div class="total-party" style="color:${p.color}">${escapeHtml(p.short)}</div>
        <div class="total-bar-track"><div class="total-bar" style="width:${width}%;background:${p.color};color:${p.color}"></div></div>
        <div class="total-number">${value}</div>
      </div>`;
    }).join('');

    const leader = sorted[0];
    const leaderValue = leader ? totals[leader.id] || 0 : 0;
    $('leaderChip').textContent = declared ? `${leader.short} LEADS • ${leaderValue}` : 'NO RESULTS YET';
    $('leaderChip').style.color = declared ? leader.color : '';
    $('majorityProgress').style.width = `${Math.min(100, leaderValue / NEWH_DATA.TOTAL_SEATS * 100)}%`;
    $('declaredCount').textContent = declared;
    $('declarationCount').textContent = `${declared} / ${NEWH_DATA.TOTAL_SEATS}`;
    $('majorityNumber').textContent = NEWH_DATA.MAJORITY;
  }

  function renderProjection(state) {
    $('projectionCard').classList.toggle('hidden', !state.broadcast.showPredictions);
    if (!state.broadcast.showPredictions) return;
    const totals = projectedTotals(state);
    const sorted = [...state.parties].sort((a,b) => (totals[b.id] || 0) - (totals[a.id] || 0));
    $('projectionGrid').innerHTML = sorted.map(p => `<div class="projection-pill"><span style="color:${p.color}">${escapeHtml(p.short)}</span><strong>${totals[p.id] || 0}</strong></div>`).join('');
  }

  function renderSeatFocus(state) {
    const latestEvent = state.eventLog?.[0];
    let seat = latestEvent ? NEWH_DATA.constituencies.find(s => s.id === latestEvent.seatId) : null;
    if (!seat) {
      seat = [...NEWH_DATA.constituencies]
        .filter(s => !state.results[s.id])
        .sort((a,b) => b.predictionConfidence - a.predictionConfidence)[0] || NEWH_DATA.constituencies[0];
    }
    if (!seat) return;

    const result = state.results[seat.id];
    const predicted = partyById(state, seat.predictedWinner);
    const previous = partyById(state, seat.previousWinner);
    const winner = result ? partyById(state, result.partyId) : predicted;
    const predictionCorrect = result && result.partyId === seat.predictedWinner;
    const statusText = result
      ? (predictionCorrect ? 'PREDICTION CORRECT' : 'RESULT BEAT THE MODEL')
      : 'AWAITING DECLARATION';

    $('seatFocusContent').innerHTML = result ? `
      <div class="focus-seat-name">${escapeHtml(seat.name)}</div>
      <div class="focus-seat-region">${escapeHtml(seat.region)} • ${escapeHtml(previous.short)} previously</div>
      <div class="focus-result-block">
        <span class="focus-label">DECLARED WINNER</span>
        <strong class="focus-party" style="color:${winner.color}">${escapeHtml(winner.name)}</strong>
        <span class="focus-result-tag" style="--focus-color:${winner.color}">${escapeHtml(result.holdGain || '')}</span>
      </div>
      <div class="focus-divider"><span>${statusText}</span></div>
      <div class="focus-prediction-block">
        <span class="focus-label">PRE-DECLARATION PREDICTION</span>
        <div class="focus-prediction-party"><i style="background:${predicted.color}"></i><strong>${escapeHtml(predicted.name)}</strong></div>
        <div class="focus-prediction-stats"><span>${seat.predictionConfidence}% model confidence</span><span>${seat.predictionSwing.toFixed(1)} pt forecast swing</span></div>
      </div>` : `
      <div class="focus-seat-name">${escapeHtml(seat.name)}</div>
      <div class="focus-seat-region">${escapeHtml(seat.region)} • ${escapeHtml(previous.short)} previously</div>
      <div class="focus-result-block prediction-only">
        <span class="focus-label">CURRENT PREDICTION</span>
        <strong class="focus-party" style="color:${predicted.color}">${escapeHtml(predicted.name)}</strong>
        <span class="focus-result-tag" style="--focus-color:${predicted.color}">${seat.predictionConfidence}%</span>
      </div>
      <div class="focus-divider"><span>AWAITING DECLARATION</span></div>
      <div class="focus-prediction-block">
        <span class="focus-label">MODEL DETAIL</span>
        <div class="focus-prediction-stats stacked"><span>${seat.predictionSwing.toFixed(1)} pt forecast swing</span><span>Result will replace this prediction live</span></div>
      </div>`;
  }

  function renderDeclarations(state) {
    const items = state.eventLog.slice(0, 8);
    $('declarationLog').innerHTML = items.length ? items.map(event => {
      const p = partyById(state, event.partyId);
      const seat = NEWH_DATA.constituencies.find(s => s.id === event.seatId);
      const prediction = seat ? partyById(state, seat.predictedWinner) : null;
      const upset = seat && event.partyId !== seat.predictedWinner;
      return `<div class="declaration-item" style="--party:${p.color}">
        <div class="declaration-tag">${escapeHtml(p.short)} ${escapeHtml(event.holdGain || '')}</div>
        <div class="declaration-name">${escapeHtml(event.seatName)}</div>
        <div class="declaration-meta">${escapeHtml(event.region || '')} • ${formatClock(event.timestamp)}</div>
        ${prediction ? `<div class="declaration-prediction ${upset ? 'upset' : ''}">Predicted ${escapeHtml(prediction.short)}${upset ? ' • upset' : ''}</div>` : ''}
      </div>`;
    }).join('') : `<div class="empty-state">Waiting for the first constituency declaration.</div>`;

    const latest = items[0];
    $('tickerText').textContent = latest
      ? `${partyById(state, latest.partyId).name.toUpperCase()} ${latest.holdGain} ${latest.seatName} • ${Object.keys(state.results).length} OF 640 DECLARED • ${state.broadcast.strap}`
      : `WAITING FOR THE FIRST DECLARATION • ${state.year} NEW H GENERAL ELECTION • ${state.broadcast.strap}`;
  }

  function renderExitPoll(state, source) {
    const overlay = $('exitOverlay');
    const visible = Boolean(state.exitPoll.visible && state.mode === 'general');
    overlay.classList.toggle('visible', visible);
    overlay.setAttribute('aria-hidden', visible ? 'false' : 'true');
    $('exitTitle').textContent = state.exitPoll.title || 'EXIT POLL';
    $('exitYear').textContent = state.year;
    if (state.exitPoll.sequence !== previousExitSequence || source === 'initial') {
      previousExitSequence = state.exitPoll.sequence;
      const rankedRows = state.exitPoll.rows
        .filter(r => state.parties.some(p => p.id === r.partyId))
        .sort((a,b) => Number(b.seats || 0) - Number(a.seats || 0))
        .slice(0, 8);

      let featuredPartyId = state.exitPoll.centrePartyId || 'auto';
      if (featuredPartyId === 'auto' || !rankedRows.some(r => r.partyId === featuredPartyId)) {
        featuredPartyId = rankedRows[0]?.partyId || '';
      }
      const featuredRow = rankedRows.find(r => r.partyId === featuredPartyId);
      const otherRows = rankedRows.filter(r => r.partyId !== featuredPartyId);
      const centreIndex = Math.floor(rankedRows.length / 2);
      const rows = featuredRow
        ? [...otherRows.slice(0, centreIndex), featuredRow, ...otherRows.slice(centreIndex)]
        : rankedRows;

      $('exitCards').innerHTML = rows.map((row, i) => {
        const p = partyById(state, row.partyId);
        const featuredClass = row.partyId === featuredPartyId ? ' exit-card-featured' : '';
        const featureStyle = row.partyId === featuredPartyId ? 'scale:1.06;z-index:4;' : '';
        return `<article class="exit-card${featuredClass}" style="--party:${p.color};--delay:${(i * .11 + .08).toFixed(2)}s;${featureStyle}">
          <div class="exit-card-shell"><div class="exit-card-inner"><div class="exit-card-copy">
            <div class="exit-party">${escapeHtml(p.name)}</div>
            <div class="exit-seats">${Number(row.seats || 0)}</div>
            <div class="exit-seat-label">Seats</div>
          </div></div></div>
        </article>`;
      }).join('');
    }
  }

  function renderWinner(state, source) {
    const overlay = $('winnerOverlay');
    const visible = Boolean(state.winner.visible && state.mode === 'general');
    overlay.classList.toggle('visible', visible);
    overlay.setAttribute('aria-hidden', visible ? 'false' : 'true');
    const party = partyById(state, state.winner.partyId);
    overlay.style.setProperty('--winner-color', party.color);
    $('winnerParty').textContent = party.name;
    $('winnerParty').style.color = '#fff';
    $('winnerSeats').textContent = Number(state.winner.seats || 0);
    $('winnerYear').textContent = `NEW H • ${state.year}`;
    if (state.winner.sequence !== previousWinnerSequence && visible) {
      previousWinnerSequence = state.winner.sequence;
      const content = overlay.querySelector('.winner-content');
      content.style.transition = 'none';
      content.style.opacity = '0';
      content.style.transform = 'scale(1.12) translateY(15px)';
      requestAnimationFrame(() => requestAnimationFrame(() => {
        content.style.transition = '';
        content.style.opacity = '';
        content.style.transform = '';
      }));
    }
  }

  function renderCouncil(state) {
    const results = state.council.results || {};
    const resultValues = Object.values(results);
    $('councilsDeclared').textContent = resultValues.length;

    const controls = Object.fromEntries(state.parties.map(p => [p.id, 0]));
    resultValues.forEach(r => controls[r.partyId] = (controls[r.partyId] || 0) + 1);
    const sorted = [...state.parties].sort((a,b) => (controls[b.id] || 0) - (controls[a.id] || 0));
    $('councilTotals').innerHTML = sorted.map(p => {
      const net = Number(state.council.partyTotals?.[p.id] || 0);
      return `<div class="council-total"><div class="council-total-left"><i class="swatch" style="background:${p.color}"></i><div><strong>${escapeHtml(p.short)}</strong><div class="muted-copy">${net >= 0 ? '+' : ''}${net} councillors</div></div></div><strong>${controls[p.id] || 0}</strong></div>`;
    }).join('');

    const events = (state.council.eventLog || []).slice(0, 8);
    $('councilLog').innerHTML = events.length ? events.map(event => {
      const p = partyById(state, event.partyId);
      return `<div class="declaration-item" style="--party:${p.color}"><div class="declaration-tag">${escapeHtml(p.short)} ${escapeHtml(event.change || '')}</div><div class="declaration-name">${escapeHtml(event.councilName)}</div><div class="declaration-meta">${escapeHtml(event.region)} • ${formatClock(event.timestamp)}</div></div>`;
    }).join('') : `<div class="empty-state">Waiting for the first council declaration.</div>`;

    $('countyBlocks').innerHTML = NEWH_DATA.regions.map(region => {
      const regionCouncils = NEWH_DATA.councils.filter(c => c.regionId === region.id);
      const regionResults = regionCouncils.map(c => results[c.id]).filter(Boolean);
      const counts = Object.fromEntries(state.parties.map(p => [p.id, 0]));
      regionResults.forEach(r => counts[r.partyId] = (counts[r.partyId] || 0) + 1);
      const leaders = [...state.parties].sort((a,b) => (counts[b.id] || 0) - (counts[a.id] || 0));
      const segments = leaders.slice(0, 5).map(p => {
        const h = regionResults.length ? Math.max(4, ((counts[p.id] || 0) / Math.max(1, regionCouncils.length)) * 58) : 4;
        return `<i class="county-control-segment" title="${escapeHtml(p.name)}" style="height:${h}px;background:${p.color};opacity:${counts[p.id] ? 1 : .15}"></i>`;
      }).join('');
      return `<div class="county-block"><h3>${escapeHtml(region.name)}</h3><div class="county-control-stack">${segments}</div><span class="muted-copy">${regionResults.length} / ${regionCouncils.length} declared</span></div>`;
    }).join('');
  }

  function renderMode(state) {
    const general = state.mode === 'general';
    $('generalMode').classList.toggle('hidden', !general);
    $('councilMode').classList.toggle('hidden', general);
    $('yearLabel').textContent = state.year;
    $('councilYearLabel').textContent = state.year;
    document.title = general ? `${state.year} New H General Election` : `${state.year} New H Council Elections`;
  }

  function renderCloud() {
    const info = ElectionStore.getCloudInfo();
    const el = $('cloudIndicator');
    if (info.status === 'live') { el.textContent = 'LIVE SYNC'; el.style.color = '#098c48'; }
    else if (info.status === 'error') { el.textContent = 'SYNC ERROR'; el.style.color = '#c92346'; }
    else { el.textContent = 'LOCAL'; el.style.color = ''; }
  }

  function render(state, source) {
    renderMode(state);
    $('headline').textContent = state.broadcast.headline || 'NEW H DECIDES';
    $('ticker').classList.toggle('hidden', !state.broadcast.showTicker);
    renderLegend(state);
    updateMap(state);
    renderTotals(state);
    renderProjection(state);
    renderSeatFocus(state);
    renderDeclarations(state);
    renderExitPoll(state, source);
    renderWinner(state, source);
    renderCouncil(state);
    renderCloud();
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));
  }

  function formatClock(ts) {
    if (!ts) return 'LIVE';
    try { return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); }
    catch (_) { return 'LIVE'; }
  }

  const initial = ElectionStore.getState();
  buildMap(initial);
  ElectionStore.subscribe(render);
})();
