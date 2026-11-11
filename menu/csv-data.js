// Export / Import CSV Data panel. The GUI cannot write files for a module, so a button only
// records a request (action + a time stamp); the game carries it out once at its next start
// and writes what happened to ucp/.cache/custom-skirmish-trails-requests.json.

const CSV_DATA_STATUS_FILE = 'ucp/.cache/custom-skirmish-trails-requests.json';
let csvDataPending = null;

SANDBOX_FUNCTIONS.getConfig = () =>
  csvDataPending === null
    ? {}
    : { action: csvDataPending.action, request: csvDataPending.request };

function csvDataText(id, text) {
  const element = document.getElementById(id);
  if (element) element.textContent = text;
}

function csvDataRequest(action) {
  csvDataPending = { action, request: new Date().toISOString() };
  for (const id of ['export', 'import']) {
    const button = document.getElementById(id);
    if (button) button.classList.toggle('chosen', id === action);
  }
  const word = action === 'export' ? 'Export' : 'Import';
  csvDataText(
    'pending',
    `${word} requested. Press "Save and close", then start the game once to run it.`,
  );
}

async function csvDataShowLast(trail) {
  let text = null;
  try {
    text = await HOST_FUNCTIONS.getTextFile(CSV_DATA_STATUS_FILE);
  } catch (e) {
    text = null;
  }
  if (!text) return;
  let status;
  try {
    status = JSON.parse(text)[trail];
  } catch (e) {
    return;
  }
  if (!status || !status.action) return;
  const word = status.action === 'export' ? 'export' : 'import';
  const lines = [`Last ${word} (${status.time || 'unknown time'}):`];
  for (const line of status.results || []) lines.push(`- ${line}`);
  csvDataText('last', lines.join('\n'));
}

addEventListener('INIT_DONE', async () => {
  const root = document.getElementById('csv-data');
  const trail = root ? root.dataset.trail : '';
  const exportButton = document.getElementById('export');
  const importButton = document.getElementById('import');
  if (exportButton) exportButton.onclick = () => csvDataRequest('export');
  if (importButton) importButton.onclick = () => csvDataRequest('import');

  try {
    const config = await HOST_FUNCTIONS.getCurrentConfig();
    const values = { ...(config.baseline || {}), ...(config.user || {}) };
    if (values.action && values.request) {
      csvDataText(
        'pending',
        `Saved request: ${values.action} (${values.request}). It runs once, at the next game start.`,
      );
    }
  } catch (e) {
    // no saved request
  }
  await csvDataShowLast(trail);
});
