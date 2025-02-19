local helpers = require('test.functional.helpers')(after_each)

local luv = require('luv')

local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local command = helpers.command
local exc_exec = helpers.exc_exec
local bufmeths = helpers.bufmeths
local curbufmeths = helpers.curbufmeths
local curwinmeths = helpers.curwinmeths
local curtabmeths = helpers.curtabmeths
local get_pathsep = helpers.get_pathsep
local rmdir = helpers.rmdir
local pcall_err = helpers.pcall_err
local mkdir = helpers.mkdir

local fname = 'Xtest-functional-eval-buf_functions'
local fname2 = fname .. '.2'
local dirname = fname .. '.d'

before_each(clear)

for _, func in ipairs({
  'bufname(%s)',
  'bufnr(%s)',
  'bufwinnr(%s)',
  'getbufline(%s, 1)',
  'getbufvar(%s, "changedtick")',
  'setbufvar(%s, "f", 0)',
}) do
  local funcname = func:match('%w+')
  describe(funcname .. '() function', function()
    it('errors out when receives v:true/v:false/v:null', function()
      -- Not compatible with Vim: in Vim it always results in buffer not found
      -- without any error messages.
      for _, var in ipairs({ 'v:true', 'v:false' }) do
        eq(
          'Vim(call):E5299: Expected a Number or a String, Boolean found',
          exc_exec('call ' .. func:format(var))
        )
      end
      eq(
        'Vim(call):E5300: Expected a Number or a String',
        exc_exec('call ' .. func:format('v:null'))
      )
    end)
    it('errors out when receives invalid argument', function()
      eq(
        'Vim(call):E745: Expected a Number or a String, List found',
        exc_exec('call ' .. func:format('[]'))
      )
      eq(
        'Vim(call):E728: Expected a Number or a String, Dictionary found',
        exc_exec('call ' .. func:format('{}'))
      )
      eq(
        'Vim(call):E805: Expected a Number or a String, Float found',
        exc_exec('call ' .. func:format('0.0'))
      )
      eq(
        'Vim(call):E703: Expected a Number or a String, Funcref found',
        exc_exec('call ' .. func:format('function("tr")'))
      )
    end)
  end)
end

describe('bufname() function', function()
  it('returns empty string when buffer was not found', function()
    command('file ' .. fname)
    eq('', funcs.bufname(2))
    eq('', funcs.bufname('non-existent-buffer'))
    eq('', funcs.bufname('#'))
    command('edit ' .. fname2)
    eq(2, funcs.bufnr('%'))
    eq('', funcs.bufname('X'))
  end)
  before_each(function()
    mkdir(dirname)
  end)
  after_each(function()
    rmdir(dirname)
  end)
  it('returns expected buffer name', function()
    eq('', funcs.bufname('%')) -- Buffer has no name yet
    command('file ' .. fname)
    local wd = luv.cwd()
    local sep = get_pathsep()
    local curdirname = funcs.fnamemodify(wd, ':t')
    for _, arg in ipairs({ '%', 1, 'X', wd }) do
      eq(fname, funcs.bufname(arg))
      meths.set_current_dir('..')
      eq(curdirname .. sep .. fname, funcs.bufname(arg))
      meths.set_current_dir(curdirname)
      meths.set_current_dir(dirname)
      eq(wd .. sep .. fname, funcs.bufname(arg))
      meths.set_current_dir('..')
      eq(fname, funcs.bufname(arg))
      command('enew')
    end
    eq('', funcs.bufname('%'))
    eq('', funcs.bufname('$'))
    eq(2, funcs.bufnr('%'))
  end)
end)

describe('bufnr() function', function()
  it('returns -1 when buffer was not found', function()
    command('file ' .. fname)
    eq(-1, funcs.bufnr(2))
    eq(-1, funcs.bufnr('non-existent-buffer'))
    eq(-1, funcs.bufnr('#'))
    command('edit ' .. fname2)
    eq(2, funcs.bufnr('%'))
    eq(-1, funcs.bufnr('X'))
  end)
  it('returns expected buffer number', function()
    eq(1, funcs.bufnr('%'))
    command('file ' .. fname)
    local wd = luv.cwd()
    local curdirname = funcs.fnamemodify(wd, ':t')
    eq(1, funcs.bufnr(fname))
    eq(1, funcs.bufnr(wd))
    eq(1, funcs.bufnr(curdirname))
    eq(1, funcs.bufnr('X'))
  end)
  it('returns number of last buffer with "$"', function()
    eq(1, funcs.bufnr('$'))
    command('new')
    eq(2, funcs.bufnr('$'))
    command('new')
    eq(3, funcs.bufnr('$'))
    command('only')
    eq(3, funcs.bufnr('$'))
    eq(3, funcs.bufnr('%'))
    command('buffer 1')
    eq(3, funcs.bufnr('$'))
    eq(1, funcs.bufnr('%'))
    command('bwipeout 2')
    eq(3, funcs.bufnr('$'))
    eq(1, funcs.bufnr('%'))
    command('bwipeout 3')
    eq(1, funcs.bufnr('$'))
    eq(1, funcs.bufnr('%'))
    command('new')
    eq(4, funcs.bufnr('$'))
  end)
end)

describe('bufwinnr() function', function()
  it('returns -1 when buffer was not found', function()
    command('file ' .. fname)
    eq(-1, funcs.bufwinnr(2))
    eq(-1, funcs.bufwinnr('non-existent-buffer'))
    eq(-1, funcs.bufwinnr('#'))
    command('split ' .. fname2) -- It would be OK if there was one window
    eq(2, funcs.bufnr('%'))
    eq(-1, funcs.bufwinnr('X'))
  end)
  before_each(function()
    mkdir(dirname)
  end)
  after_each(function()
    rmdir(dirname)
  end)
  it('returns expected window number', function()
    eq(1, funcs.bufwinnr('%'))
    command('file ' .. fname)
    command('vsplit')
    command('split ' .. fname2)
    eq(2, funcs.bufwinnr(fname))
    eq(1, funcs.bufwinnr(fname2))
    eq(-1, funcs.bufwinnr(fname:sub(1, #fname - 1)))
    meths.set_current_dir(dirname)
    eq(2, funcs.bufwinnr(fname))
    eq(1, funcs.bufwinnr(fname2))
    eq(-1, funcs.bufwinnr(fname:sub(1, #fname - 1)))
    eq(1, funcs.bufwinnr('%'))
    eq(2, funcs.bufwinnr(1))
    eq(1, funcs.bufwinnr(2))
    eq(-1, funcs.bufwinnr(3))
    eq(1, funcs.bufwinnr('$'))
  end)
end)

describe('getbufline() function', function()
  it('returns empty list when buffer was not found', function()
    command('file ' .. fname)
    eq({}, funcs.getbufline(2, 1))
    eq({}, funcs.getbufline('non-existent-buffer', 1))
    eq({}, funcs.getbufline('#', 1))
    command('edit ' .. fname2)
    eq(2, funcs.bufnr('%'))
    eq({}, funcs.getbufline('X', 1))
  end)
  it('returns empty list when range is invalid', function()
    eq({}, funcs.getbufline(1, 0))
    curbufmeths.set_lines(0, 1, false, { 'foo', 'bar', 'baz' })
    eq({}, funcs.getbufline(1, 2, 1))
    eq({}, funcs.getbufline(1, -10, -20))
    eq({}, funcs.getbufline(1, -2, -1))
    eq({}, funcs.getbufline(1, -1, 9999))
  end)
  it('returns expected lines', function()
    meths.set_option_value('hidden', true, {})
    command('file ' .. fname)
    curbufmeths.set_lines(0, 1, false, { 'foo\0', '\0bar', 'baz' })
    command('edit ' .. fname2)
    curbufmeths.set_lines(0, 1, false, { 'abc\0', '\0def', 'ghi' })
    eq({ 'foo\n', '\nbar', 'baz' }, funcs.getbufline(1, 1, 9999))
    eq({ 'abc\n', '\ndef', 'ghi' }, funcs.getbufline(2, 1, 9999))
    eq({ 'foo\n', '\nbar', 'baz' }, funcs.getbufline(1, 1, '$'))
    eq({ 'baz' }, funcs.getbufline(1, '$', '$'))
    eq({ 'baz' }, funcs.getbufline(1, '$', 9999))
  end)
end)

describe('getbufvar() function', function()
  it('returns empty list when buffer was not found', function()
    command('file ' .. fname)
    eq('', funcs.getbufvar(2, '&autoindent'))
    eq('', funcs.getbufvar('non-existent-buffer', '&autoindent'))
    eq('', funcs.getbufvar('#', '&autoindent'))
    command('edit ' .. fname2)
    eq(2, funcs.bufnr('%'))
    eq('', funcs.getbufvar('X', '&autoindent'))
  end)
  it('returns empty list when variable/option/etc was not found', function()
    command('file ' .. fname)
    eq('', funcs.getbufvar(1, '&autondent'))
    eq('', funcs.getbufvar(1, 'changedtic'))
  end)
  it('returns expected option value', function()
    eq(0, funcs.getbufvar(1, '&autoindent'))
    eq(0, funcs.getbufvar(1, '&l:autoindent'))
    eq(0, funcs.getbufvar(1, '&g:autoindent'))
    -- Also works with global-only options
    eq(1, funcs.getbufvar(1, '&hidden'))
    eq(1, funcs.getbufvar(1, '&l:hidden'))
    eq(1, funcs.getbufvar(1, '&g:hidden'))
    -- Also works with window-local options
    eq(0, funcs.getbufvar(1, '&number'))
    eq(0, funcs.getbufvar(1, '&l:number'))
    eq(0, funcs.getbufvar(1, '&g:number'))
    command('new')
    -- But with window-local options it probably does not what you expect
    command('setl number')
    -- (note that current window’s buffer is 2, but getbufvar() receives 1)
    eq({ id = 2 }, curwinmeths.get_buf())
    eq(1, funcs.getbufvar(1, '&number'))
    eq(1, funcs.getbufvar(1, '&l:number'))
    -- You can get global value though, if you find this useful.
    eq(0, funcs.getbufvar(1, '&g:number'))
  end)
  it('returns expected variable value', function()
    eq(2, funcs.getbufvar(1, 'changedtick'))
    curbufmeths.set_lines(0, 1, false, { 'abc\0', '\0def', 'ghi' })
    eq(3, funcs.getbufvar(1, 'changedtick'))
    curbufmeths.set_var('test', true)
    eq(true, funcs.getbufvar(1, 'test'))
    eq({ test = true, changedtick = 3 }, funcs.getbufvar(1, ''))
    command('new')
    eq(3, funcs.getbufvar(1, 'changedtick'))
    eq(true, funcs.getbufvar(1, 'test'))
    eq({ test = true, changedtick = 3 }, funcs.getbufvar(1, ''))
  end)
end)

describe('setbufvar() function', function()
  it('throws the error or ignores the input when buffer was not found', function()
    command('file ' .. fname)
    eq(0, exc_exec('call setbufvar(2, "&autoindent", 0)'))
    eq(
      'Vim(call):E94: No matching buffer for non-existent-buffer',
      exc_exec('call setbufvar("non-existent-buffer", "&autoindent", 0)')
    )
    eq(0, exc_exec('call setbufvar("#", "&autoindent", 0)'))
    command('edit ' .. fname2)
    eq(2, funcs.bufnr('%'))
    eq(
      'Vim(call):E93: More than one match for X',
      exc_exec('call setbufvar("X", "&autoindent", 0)')
    )
  end)
  it('may set options, including window-local and global values', function()
    local buf1 = meths.get_current_buf()
    eq(false, meths.get_option_value('number', {}))
    command('split')
    command('new')
    eq(2, bufmeths.get_number(curwinmeths.get_buf()))
    funcs.setbufvar(1, '&number', true)
    local windows = curtabmeths.list_wins()
    eq(false, meths.get_option_value('number', { win = windows[1].id }))
    eq(true, meths.get_option_value('number', { win = windows[2].id }))
    eq(false, meths.get_option_value('number', { win = windows[3].id }))
    eq(false, meths.get_option_value('number', { win = meths.get_current_win().id }))

    eq(true, meths.get_option_value('hidden', {}))
    funcs.setbufvar(1, '&hidden', 0)
    eq(false, meths.get_option_value('hidden', {}))

    eq(false, meths.get_option_value('autoindent', { buf = buf1.id }))
    funcs.setbufvar(1, '&autoindent', true)
    eq(true, meths.get_option_value('autoindent', { buf = buf1.id }))
    eq('Vim(call):E355: Unknown option: xxx', exc_exec('call setbufvar(1, "&xxx", 0)'))
  end)
  it('may set variables', function()
    local buf1 = meths.get_current_buf()
    command('split')
    command('new')
    eq(2, curbufmeths.get_number())
    funcs.setbufvar(1, 'number', true)
    eq(true, bufmeths.get_var(buf1, 'number'))
    eq('Vim(call):E461: Illegal variable name: b:', exc_exec('call setbufvar(1, "", 0)'))
    eq(true, bufmeths.get_var(buf1, 'number'))
    eq(
      'Vim:E46: Cannot change read-only variable "b:changedtick"',
      pcall_err(funcs.setbufvar, 1, 'changedtick', true)
    )
    eq(2, funcs.getbufvar(1, 'changedtick'))
  end)
  it('throws error when setting a string option to a boolean value vim-patch:9.0.0090', function()
    eq('Vim:E928: String required', pcall_err(funcs.setbufvar, '', '&errorformat', true))
  end)
end)
