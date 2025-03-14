# Just configuration file for running commands.
#
# For more information, visit https://just.systems.

set windows-shell := ['powershell.exe', '-NoLogo', '-Command']

# List all commands available in justfile.
list:
  just --list

# Execute all commands.
all: setup format lint docs test

# Build documentation.
docs:
  cp -r src/install assets/
  npx vitepress build .

# Check code formatting.
[unix]
format:
  npx prettier --check .
  shfmt --diff --indent 2 install.sh src tests

# Check code formatting.
[windows]
format:
  npx prettier --check .
  Invoke-ScriptAnalyzer -EnableExit -Path install.ps1 -Settings CodeFormatting
  Invoke-ScriptAnalyzer -EnableExit -Recurse -Path src -Settings CodeFormatting
  Invoke-ScriptAnalyzer -EnableExit -Recurse -Path tests -Settings CodeFormatting

# Run code analyses.
[unix]
lint:
  #!/usr/bin/env sh
  set -eu
  bats_files="$(find . -type f -name '*.bats' -not -path '*/node_modules/*')"
  for file in ${bats_files}; do
    shellcheck --shell bash "${file}"
  done
  sh_files="$(find . -type f -name '*.sh' -not -path '*/node_modules/*')"
  for file in ${sh_files}; do
    shellcheck "${file}"
  done

# Run code analyses.
[windows]
lint:
  Invoke-ScriptAnalyzer -EnableExit -Path install.ps1 -Settings PSScriptAnalyzerSettings.psd1
  Invoke-ScriptAnalyzer -EnableExit -Recurse -Path src -Settings PSScriptAnalyzerSettings.psd1
  Invoke-ScriptAnalyzer -EnableExit -Recurse -Path tests -Settings PSScriptAnalyzerSettings.psd1

# Install development dependencies.
setup: _setup-shell
  node --version
  npm --version
  npm ci

[unix]
_setup-shell:
  #!/usr/bin/env sh
  set -eu
  if [ "$(id -u)" -eq 0 ]; then
    super=''
  elif [ -x "$(command -v sudo)" ]; then
    super='sudo'
  elif [ -x "$(command -v doas)" ]; then
    super='doas'
  fi
  arch="$(uname -m | sed s/x86_64/amd64/ | sed s/x64/amd64/ | sed s/aarch64/arm64/)"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [ ! -x "$(command -v nu)" ]; then
    ./src/install/nushell.sh --user
  fi
  echo "Nushell $(nu --version)"
  if [ ! -x "$(command -v jq)" ]; then
    if [ -x "$(command -v apk)" ]; then
      ${super:+"${super}"} apk update
      ${super:+"${super}"} apk add jq
    elif [ -x "$(command -v apt-get)" ]; then
      ${super:+"${super}"} apt-get update
      ${super:+"${super}"} apt-get install --yes jq
    elif [ -x "$(command -v brew)" ]; then
      brew install jq
    elif [ -x "$(command -v dnf)" ]; then
      ${super:+"${super}"} dnf check-update || {
        code="$?"
        [ "${code}" -ne 100 ] && exit "${code}"
      }
      ${super:+"${super}"} dnf install --assumeyes jq
    elif [ -x "$(command -v pacman)" ]; then
      ${super:+"${super}"} pacman --noconfirm --refresh --sync --sysupgrade
      ${super:+"${super}"} pacman --noconfirm --sync jq
    elif [ -x "$(command -v pkg)" ]; then
      ${super:+"${super}"} pkg update
      ${super:+"${super}"} pkg install --yes jq
    elif [ -x "$(command -v zypper)" ]; then
      ${super:+"${super}"} zypper update --no-confirm
      ${super:+"${super}"} zypper install --no-confirm jq
    fi
  fi
  jq --version
  if [ ! -x "$(command -v shfmt)" ]; then
    if [ -x "$(command -v brew)" ]; then
      brew install shfmt
    elif [ -x "$(command -v pkg)" ]; then
      ${super:+"${super}"} pkg update
      ${super:+"${super}"} pkg install --yes shfmt
    else
      shfmt_version="$(curl  --fail --location --show-error \
        https://formulae.brew.sh/api/formula/shfmt.json |
        jq --exit-status --raw-output .versions.stable)"
      curl --fail --location --show-error --output /tmp/shfmt \
        "https://github.com/mvdan/sh/releases/download/v${shfmt_version}/shfmt_v${shfmt_version}_${os}_${arch}"
      ${super:+"${super}"} install /tmp/shfmt /usr/local/bin/shfmt
    fi
  fi
  shfmt --version

[windows]
_setup-shell:
  #!powershell.exe
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  $PSNativeCommandUseErrorActionPreference = $True
  # If executing task from PowerShell Core, error such as "'Install-Module'
  # command was found in the module 'PowerShellGet', but the module could not be
  # loaded" unless earlier versions of PackageManagement and PowerShellGet are
  # imported.
  Import-Module -MaximumVersion 1.1.0 -MinimumVersion 1.0.0 PackageManagement
  Import-Module -MaximumVersion 1.9.9 -MinimumVersion 1.0.0 PowerShellGet
  Get-PackageProvider -Force Nuget | Out-Null
  If (-Not (Get-Command -ErrorAction SilentlyContinue nu)) {
    & src/install/nushell.ps1 --user
  }
  Write-Output "Nushell $(nu --version)"
  If (-Not (Get-Module -ListAvailable -FullyQualifiedName @{ModuleName="PSScriptAnalyzer";ModuleVersion="1.0.0"})) {
    Install-Module -Force -MinimumVersion 1.0.0 -Name PSScriptAnalyzer
  }
  If (-Not (Get-Module -ListAvailable -FullyQualifiedName @{ModuleName="Pester";ModuleVersion="5.0.0"})) {
    Install-Module -Force -SkipPublisherCheck -MinimumVersion 5.0.0 -Name Pester
  }
  Install-Module -Force -Name PSScriptAnalyzer
  Install-Module -Force -SkipPublisherCheck -Name Pester

# Run test suites.
[unix]
test:
  npx bats --recursive tests

# Run test suites.
[windows]
test:
  Invoke-Pester -CI -Output Detailed tests
