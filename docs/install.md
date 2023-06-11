# Installation

Shell Scripts provides Bash and PowerShell install scripts to download any
collection of scripts from the repository. The following command shows the list
of downloadable scripts from the repository.

::: code-group

```bash [FreeBSD]
curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh | bash -s -- --list
```

```bash [Linux]
curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh | bash -s -- --list
```

```bash [MacOS]
curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh | bash -s -- --list
```

```powershell [Windows]
powershell { & ([ScriptBlock]::Create((iwr -useb https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.ps1))) "--list" }
```

:::

The following command will install the packup script. Other scripts can be
installed by replacing the `packup` argument.

::: code-group

```bash [FreeBSD]
curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh | bash -s -- packup
```

```bash [Linux]
curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh | bash -s -- packup
```

```bash [MacOS]
curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh | bash -s -- packup
```

```powershell [Windows]
powershell { & ([ScriptBlock]::Create((iwr -useb https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.ps1))) "packup" }
```

:::

::: warning

On Windows, PowerShell will need to run as administrator if the `--user` flag is
not used. Additionally, the security policy must allow for running remote
PowerShell scripts. If needed, the following command will update the security
policy for the current user.

:::

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
