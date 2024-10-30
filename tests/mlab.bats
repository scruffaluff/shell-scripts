#!/usr/bin/env bats

setup() {
  export PATH="${BATS_TEST_DIRNAME}/..:${PATH}"
  load '../node_modules/bats-assert/load'
  load '../node_modules/bats-support/load'

  export MLAB_PROGRAM='/bin/matlab'
  export SHELL_SCRIPTS_NOLOG='true'
}

@test 'Mlab argumentless call contains no commands' {
  local actual expected
  expected='/bin/matlab -nodisplay -nosplash'

  actual="$(bash src/mlab.sh run --echo)"
  assert_equal "${actual}" "${expected}"
}

@test 'Mlab debug call contains sets breakpoint on error' {
  local actual expected
  expected='/bin/matlab -nodisplay -nosplash -r dbstop if error;'

  actual="$(bash src/mlab.sh run --echo --debug)"
  assert_equal "${actual}" "${expected}"
}

@test 'Mlab function call contains one batch command' {
  local actual expected
  expected='/bin/matlab -nodesktop -nosplash -batch script'

  actual="$(bash src/mlab.sh run --echo script)"
  assert_equal "${actual}" "${expected}"
}

@test 'Mlab genpath option call contains multiple path commands' {
  local actual expected
  expected="/bin/matlab -nodisplay -nosplash -r addpath(genpath('/tmp')); "

  actual="$(bash src/mlab.sh run --echo --genpath /tmp)"
  assert_equal "${actual}" "${expected}"
}

@test 'Mlab path option call contains path command' {
  local actual expected
  expected="/bin/matlab -nodisplay -nosplash -r addpath('/tmp'); "

  actual="$(bash src/mlab.sh run --echo --addpath /tmp)"
  assert_equal "${actual}" "${expected}"
}

@test 'Mlab script call contains one batch command' {
  local actual expected
  expected="/bin/matlab -nodesktop -nosplash -batch addpath('src'); script"

  actual="$(bash src/mlab.sh run --echo src/script.m)"
  assert_equal "${actual}" "${expected}"
}

@test 'Mlab debug script call contains several commands' {
  local actual expected
  expected="/bin/matlab -nodisplay -nosplash -r addpath('src'); dbstop if \
error; dbstop in script; script; exit"

  actual="$(bash src/mlab.sh run --echo --debug src/script.m)"
  assert_equal "${actual}" "${expected}"
}
