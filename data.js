// NEW H Election Night — deterministic fictional election data.
// 16 counties × 40 constituencies = 640 seats.

window.NEWH_DATA = (() => {
  const regions = [
    { id: 'northmarch', name: 'Northmarch', short: 'NM' },
    { id: 'southmarch', name: 'Southmarch', short: 'SM' },
    { id: 'westvale', name: 'West Vale', short: 'WV' },
    { id: 'eastvale', name: 'East Vale', short: 'EV' },
    { id: 'crownshire', name: 'Crownshire', short: 'CR' },
    { id: 'redmere', name: 'Redmere', short: 'RM' },
    { id: 'larkshire', name: 'Larkshire', short: 'LK' },
    { id: 'wexfordcoast', name: 'Wexford Coast', short: 'WC' },
    { id: 'halcyon', name: 'Halcyon', short: 'HA' },
    { id: 'greyfen', name: 'Greyfen', short: 'GF' },
    { id: 'ashbourne', name: 'Ashbourne', short: 'AB' },
    { id: 'kingsmere', name: 'Kingsmere', short: 'KM' },
    { id: 'stonehaven', name: 'Stonehaven', short: 'SH' },
    { id: 'greenwater', name: 'Greenwater', short: 'GW' },
    { id: 'moorland', name: 'Moorland', short: 'ML' },
    { id: 'newhcentral', name: 'New H Central', short: 'NH' }
  ];

  const localities = [
    'Alderwick', 'Briarfield', 'Cedarham', 'Dunmere', 'Elmstead',
    'Foxbridge', 'Glenford', 'Hartwick', 'Ivycross', 'Juniper Bay'
  ];

  const quarters = ['North', 'South', 'East', 'West'];

  const defaultParties = [
    { id: 'con', name: 'Conservative', short: 'CON', color: '#1188d8' },
    { id: 'lab', name: 'Labour', short: 'LAB', color: '#e4003b' },
    { id: 'ld', name: 'Liberal Democrats', short: 'LD', color: '#f6b500' },
    { id: 'ref', name: 'Reform UK', short: 'REF', color: '#19d2d8' },
    { id: 'grn', name: 'Green', short: 'GRN', color: '#00a95c' },
    { id: 'uip', name: 'UIP', short: 'UIP', color: '#8c52ff' },
    { id: 'ind', name: 'Independent', short: 'IND', color: '#9ea4ad' }
  ];

  const previousCycle = ['lab', 'con', 'lab', 'con', 'ld', 'lab', 'ref', 'con', 'grn', 'lab', 'con', 'lab', 'ld', 'con', 'lab', 'uip'];
  const predictionCycle = ['lab', 'lab', 'con', 'lab', 'ld', 'lab', 'ref', 'con', 'lab', 'grn', 'con', 'lab', 'ld', 'lab', 'con', 'ref'];

  function seededNumber(seed) {
    let x = Math.sin(seed * 999.91) * 43758.5453;
    return x - Math.floor(x);
  }

  const constituencies = [];
  let index = 0;
  regions.forEach((region, rIndex) => {
    localities.forEach((locality, lIndex) => {
      quarters.forEach((quarter, qIndex) => {
        const previous = previousCycle[(index + rIndex + lIndex) % previousCycle.length];
        const predicted = predictionCycle[(index * 3 + rIndex + qIndex) % predictionCycle.length];
        const confidence = Math.round(51 + seededNumber(index + 12) * 28);
        const swing = Number((1.2 + seededNumber(index + 91) * 10.8).toFixed(1));
        constituencies.push({
          id: `seat-${String(index + 1).padStart(3, '0')}`,
          index,
          regionId: region.id,
          region: region.name,
          regionShort: region.short,
          name: `${region.name} ${locality} ${quarter}`,
          previousWinner: previous,
          predictedWinner: predicted,
          predictionConfidence: confidence,
          predictionSwing: swing
        });
        index += 1;
      });
    });
  });

  const councils = regions.flatMap((region, regionIndex) => {
    return ['City', 'Borough', 'North', 'South', 'East', 'West', 'Vale', 'District'].map((kind, i) => ({
      id: `council-${region.id}-${i + 1}`,
      regionId: region.id,
      region: region.name,
      name: `${region.name} ${kind} Council`,
      seats: 24 + ((regionIndex * 7 + i * 5) % 37),
      previousControl: previousCycle[(regionIndex + i) % previousCycle.length]
    }));
  });

  return {
    regions,
    constituencies,
    councils,
    defaultParties,
    TOTAL_SEATS: constituencies.length,
    MAJORITY: Math.floor(constituencies.length / 2) + 1
  };
})();
