return {
  cmd = require('exer.core.cmd'),
  io = require('exer.core.io'),
  log = require('exer.core.log'),
  picker = require('exer.picker'),
  runner = require('exer.core.runner'),
  tsk = require('exer.core.tsk'),
  utils = require('exer.core.utils'),
  psr = {
    toml = require('exer.core.psr.toml'),
    treesitter = require('exer.core.psr.treesitter'),
    editorconfig = require('exer.core.psr.editorconfig'),
  },
}
