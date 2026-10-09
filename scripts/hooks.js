// Add or remove awake hooks in a Claude Code / Codex hooks config.
// usage: osascript -l JavaScript hooks.js <add|remove> <claude|codex> <config.json> <awake-bin>
ObjC.import('Foundation');

const EVENTS = {
  claude: { UserPromptSubmit: 'on', PreToolUse: 'on', Stop: 'off', SessionEnd: 'off' },
  codex: { UserPromptSubmit: 'on', PreToolUse: 'on', Stop: 'off', Interrupt: 'off', SessionEnd: 'off' },
};

function readJson(path) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return text.isNil() ? {} : JSON.parse(ObjC.unwrap(text));
}

function writeJson(path, data) {
  const dir = $(path).stringByDeletingLastPathComponent;
  $.NSFileManager.defaultManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(dir, true, $(), null);
  $(JSON.stringify(data, null, 2) + '\n').writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

const isOurs = (hook) => typeof hook.command === 'string' && hook.command.includes(' hook ') && hook.command.includes('awake');

function run(argv) {
  const [mode, tool, path, bin] = argv;
  const config = readJson(path);
  const hooks = config.hooks || {};

  // Drop our previous entries everywhere, so add is idempotent and remove is clean.
  for (const event of Object.keys(hooks)) {
    hooks[event] = hooks[event]
      .map((group) => ({ ...group, hooks: (group.hooks || []).filter((h) => !isOurs(h)) }))
      .filter((group) => group.hooks.length > 0);
    if (hooks[event].length === 0) delete hooks[event];
  }

  if (mode === 'add') {
    for (const [event, action] of Object.entries(EVENTS[tool])) {
      (hooks[event] = hooks[event] || []).push({
        hooks: [{ type: 'command', command: `'${bin}' hook ${tool} ${action}`, timeout: 3 }],
      });
    }
  }

  if (Object.keys(hooks).length) config.hooks = hooks;
  else delete config.hooks;
  writeJson(path, config);
}
