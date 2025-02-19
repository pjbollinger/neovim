local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local pcall_err = helpers.pcall_err
local feed = helpers.feed
local poke_eventloop = helpers.poke_eventloop
local is_os = helpers.is_os
local meths = helpers.meths
local async_meths = helpers.async_meths
local testprg = helpers.testprg
local assert_alive = helpers.assert_alive

describe('terminal channel is closed and later released if', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  it('opened by nvim_open_term() and deleted by :bdelete!', function()
    command([[let id = nvim_open_term(0, {})]])
    local chans = eval('len(nvim_list_chans())')
    -- channel hasn't been released yet
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[bdelete! | call chansend(id, 'test')]])
    )
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by nvim_open_term(), closed by chanclose(), and deleted by pressing a key', function()
    command('let id = nvim_open_term(0, {})')
    local chans = eval('len(nvim_list_chans())')
    -- channel has been closed but not released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chanclose(id) | call chansend(id, 'test')]])
    )
    screen:expect({ any = '%[Terminal closed%]' })
    eq(chans, eval('len(nvim_list_chans())'))
    -- delete terminal
    feed('i<CR>')
    -- need to first process input
    poke_eventloop()
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after another main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by nvim_open_term(), closed by chanclose(), and deleted by :bdelete', function()
    command('let id = nvim_open_term(0, {})')
    local chans = eval('len(nvim_list_chans())')
    -- channel has been closed but not released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chanclose(id) | call chansend(id, 'test')]])
    )
    screen:expect({ any = '%[Terminal closed%]' })
    eq(chans, eval('len(nvim_list_chans())'))
    -- channel still hasn't been released yet
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[bdelete | call chansend(id, 'test')]])
    )
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by termopen(), exited, and deleted by pressing a key', function()
    command([[let id = termopen('echo')]])
    local chans = eval('len(nvim_list_chans())')
    -- wait for process to exit
    screen:expect({ any = '%[Process exited 0%]' })
    -- process has exited but channel has't been released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chansend(id, 'test')]])
    )
    eq(chans, eval('len(nvim_list_chans())'))
    -- delete terminal
    feed('i<CR>')
    -- need to first process input
    poke_eventloop()
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after another main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  -- This indirectly covers #16264
  it('opened by termopen(), exited, and deleted by :bdelete', function()
    command([[let id = termopen('echo')]])
    local chans = eval('len(nvim_list_chans())')
    -- wait for process to exit
    screen:expect({ any = '%[Process exited 0%]' })
    -- process has exited but channel hasn't been released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chansend(id, 'test')]])
    )
    eq(chans, eval('len(nvim_list_chans())'))
    -- channel still hasn't been released yet
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[bdelete | call chansend(id, 'test')]])
    )
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)
end)

it('chansend sends lines to terminal channel in proper order', function()
  clear({ args = { '--cmd', 'set laststatus=2' } })
  local screen = Screen.new(100, 20)
  screen:attach()
  local shells = is_os('win') and { 'cmd.exe', 'pwsh.exe -nop', 'powershell.exe -nop' } or { 'sh' }
  for _, sh in ipairs(shells) do
    command([[let id = termopen(']] .. sh .. [[')]])
    command([[call chansend(id, ['echo "hello"', 'echo "world"', ''])]])
    screen:expect {
      any = [[echo "hello".*echo "world"]],
    }
    command('bdelete!')
    screen:expect {
      any = '%[No Name%]',
    }
  end
end)

describe('no crash when TermOpen autocommand', function()
  local screen

  before_each(function()
    clear()
    meths.set_option_value('shell', testprg('shell-test'), {})
    command('set shellcmdflag=EXE shellredir= shellpipe= shellquote= shellxquote=')
    screen = Screen.new(60, 4)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
    })
    screen:attach()
  end)

  it('processes job exit event when using termopen()', function()
    command([[autocmd TermOpen * call input('')]])
    async_meths.command('terminal foobar')
    screen:expect {
      grid = [[
                                                                  |
      {0:~                                                           }|*2
      ^                                                            |
    ]],
    }
    feed('<CR>')
    screen:expect {
      grid = [[
      ^ready $ foobar                                              |
                                                                  |
      [Process exited 0]                                          |
                                                                  |
    ]],
    }
    feed('i<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {0:~                                                           }|*2
                                                                  |
    ]],
    }
    assert_alive()
  end)

  it('wipes buffer and processes events when using termopen()', function()
    command([[autocmd TermOpen * bwipe! | call input('')]])
    async_meths.command('terminal foobar')
    screen:expect {
      grid = [[
                                                                  |
      {0:~                                                           }|*2
      ^                                                            |
    ]],
    }
    feed('<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {0:~                                                           }|*2
                                                                  |
    ]],
    }
    assert_alive()
  end)

  it('wipes buffer and processes events when using nvim_open_term()', function()
    command([[autocmd TermOpen * bwipe! | call input('')]])
    async_meths.open_term(0, {})
    screen:expect {
      grid = [[
                                                                  |
      {0:~                                                           }|*2
      ^                                                            |
    ]],
    }
    feed('<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {0:~                                                           }|*2
                                                                  |
    ]],
    }
    assert_alive()
  end)
end)

describe('nvim_open_term', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(8, 10)
    screen:attach()
  end)

  it('with force_crlf=true converts newlines', function()
    local win = meths.get_current_win()
    local buf = meths.create_buf(false, true)
    local term = meths.open_term(buf, { force_crlf = true })
    meths.win_set_buf(win, buf)
    meths.chan_send(term, 'here\nthere\nfoo\r\nbar\n\ntest')
    screen:expect {
      grid = [[
      ^here        |
      there       |
      foo         |
      bar         |
                  |
      test        |
                  |*4
    ]],
    }
    meths.chan_send(term, '\nfirst')
    screen:expect {
      grid = [[
      ^here        |
      there       |
      foo         |
      bar         |
                  |
      test        |
      first       |
                  |*3
    ]],
    }
  end)

  it('with force_crlf=false does not convert newlines', function()
    local win = meths.get_current_win()
    local buf = meths.create_buf(false, true)
    local term = meths.open_term(buf, { force_crlf = false })
    meths.win_set_buf(win, buf)
    meths.chan_send(term, 'here\nthere')
    screen:expect { grid = [[
      ^here        |
          there   |
                  |*8
    ]] }
  end)
end)
