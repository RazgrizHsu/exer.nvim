local M = {}

local COMPILERS = {
  c = {
    binary = function(files, output, args)
      local argStr = args and table.concat(args, ' ') or ''
      return string.format('gcc %s -o "%s" %s', files, output, argStr)
    end,
  },
  cpp = {
    binary = function(files, output, args)
      local argStr = args and table.concat(args, ' ') or ''
      return string.format('g++ %s -o "%s" %s', files, output, argStr)
    end,
  },
  java = {
    class = function(files, output, args)
      local argStr = args and table.concat(args, ' ') or ''
      return string.format('javac %s -d "%s" %s', files, output, argStr)
    end,
  },
  kotlin = {
    jar = function(files, output, args)
      local argStr = args and table.concat(args, ' ') or ''
      return string.format('kotlinc %s -include-runtime -d "%s" %s', files, output, argStr)
    end,
  },
  go = {
    binary = function(files, output, args)
      local argStr = args and table.concat(args, ' ') or ''
      return string.format('go build -o "%s" %s %s', output, argStr, files)
    end,
  },
  rust = {
    binary = function(files, output, args)
      local argStr = args and table.concat(args, ' ') or ''
      return string.format('rustc "%s" -o "%s" %s', files, output, argStr)
    end,
  },
}

local INTERPRETERS = {
  ['.py'] = 'python',
  ['.rb'] = 'ruby',
  ['.sh'] = 'bash',
  ['.dart'] = 'dart',
  ['.lua'] = 'lua',
  ['.js'] = 'node',
  ['.ts'] = 'ts-node',
}

function M.inferType(entry)
  local ext = entry:match('%.([^%.]+)$')
  if not ext then return 'script' end

  local extMap = {
    c = 'binary',
    cpp = 'binary',
    cc = 'binary',
    cxx = 'binary',
    go = 'binary',
    rs = 'binary',
    java = 'class',
    kt = 'jar',
    py = 'script',
    rb = 'script',
    sh = 'script',
    dart = 'script',
    lua = 'script',
    js = 'script',
    ts = 'script',
  }

  return extMap[ext] or 'script'
end

function M.inferLang(entry)
  local ext = entry:match('%.([^%.]+)$')
  if not ext then return 'sh' end

  local langMap = {
    c = 'c',
    cpp = 'cpp',
    cc = 'cpp',
    cxx = 'cpp',
    go = 'go',
    rs = 'rust',
    java = 'java',
    kt = 'kotlin',
    py = 'python',
    rb = 'ruby',
    sh = 'sh',
    dart = 'dart',
    lua = 'lua',
    js = 'javascript',
    ts = 'typescript',
  }

  return langMap[ext] or 'sh'
end

function M.getCompiler(lang, appType)
  local langCompilers = COMPILERS[lang]
  if not langCompilers then return nil end
  return langCompilers[appType]
end

function M.getInterpreter(ext) return INTERPRETERS[ext] end

return M
