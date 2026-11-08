// File paths panel: shows the trail's file settings (trail settings file, default csv file,
// csv files per language) and clears them. The GUI's own reset only works for paths changed in
// the same GUI session, so this is the way to empty a path later.

const FILE_PATH_LABELS = {
  'settings.path': 'Trail settings file',
  'csv.path': 'Csv file (default)',
};
const filePathsCleared = new Set();
let filePathsValues = {};

SANDBOX_FUNCTIONS.getConfig = () =>
  Object.fromEntries([...filePathsCleared].map((key) => [key, '']));

function filePathLabel(key) {
  if (FILE_PATH_LABELS[key]) return FILE_PATH_LABELS[key];
  const language = key.replace(/^csv\.languages\./, '');
  return `Csv file (${language.charAt(0).toUpperCase()}${language.slice(1)})`;
}

function filePathKeys() {
  return Object.keys(filePathsValues)
    .filter((key) => key === 'settings.path' || key === 'csv.path' || key.startsWith('csv.languages.'))
    .sort((a, b) => {
      const order = (key) => (key === 'settings.path' ? 0 : key === 'csv.path' ? 1 : 2);
      return order(a) - order(b) || a.localeCompare(b);
    });
}

function filePathCurrent(key) {
  return filePathsCleared.has(key) ? '' : `${filePathsValues[key] ?? ''}`;
}

function renderFilePaths() {
  const table = document.getElementById('paths');
  table.textContent = '';
  const keys = filePathKeys().filter((key) => filePathCurrent(key) !== '' || filePathsCleared.has(key));
  if (keys.length === 0) {
    const row = table.insertRow();
    row.insertCell().textContent = 'No files are set for this trail.';
  }
  for (const key of keys) {
    const row = table.insertRow();
    row.insertCell().textContent = filePathLabel(key);
    const value = row.insertCell();
    value.textContent = filePathCurrent(key) || '(cleared)';
    value.className = 'path';
    const action = row.insertCell();
    if (!filePathsCleared.has(key)) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = 'Clear';
      button.onclick = () => {
        filePathsCleared.add(key);
        renderFilePaths();
      };
      action.appendChild(button);
    }
  }

  const settingsSet = filePathCurrent('settings.path') !== '';
  document.getElementById('notice').textContent = settingsSet
    ? 'A trail settings file is set: if it has trail_csv_files, those files are used and the csv paths below and in "Csv files" are only a fallback.'
    : '';
  document.getElementById('status').textContent = filePathsCleared.size
    ? `${filePathsCleared.size} path(s) will be cleared when you press "Save and close".`
    : '';
}

addEventListener('INIT_DONE', async () => {
  try {
    const config = await HOST_FUNCTIONS.getCurrentConfig();
    filePathsValues = { ...(config.baseline || {}), ...(config.user || {}) };
  } catch (e) {
    filePathsValues = {};
  }
  document.getElementById('clear-csv').onclick = () => {
    for (const key of filePathKeys()) {
      if (key !== 'settings.path' && filePathCurrent(key) !== '') filePathsCleared.add(key);
    }
    renderFilePaths();
  };
  renderFilePaths();
});
