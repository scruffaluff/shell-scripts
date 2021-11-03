# Installation

Shell Scripts provides Bash and PowerShell install scripts to download any
collection of scripts from the repository. The following command shows the list
of downloadable scripts from the repository.

<code-group>
<code-block title="FreeBSD" active>
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- --list
```
</code-block>

<code-block title="Linux" active>
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- --list
```
</code-block>

<code-block title="MacOS">
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- --list
```
</code-block>

<code-block title="Windows">
```powershell
powershell { & ([ScriptBlock]::Create((iwr -useb https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.ps1))) "--list" }
```
</code-block>
</code-group>

The following command will install the packup script. Other scripts can be
installed by replacing the `packup` argument.

<code-group>
<code-block title="FreeBSD" active>
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- packup
```
</code-block>

<code-block title="Linux" active>
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- packup
```
</code-block>

<code-block title="MacOS">
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- packup
```
</code-block>

<code-block title="Windows">
```powershell
powershell { & ([ScriptBlock]::Create((iwr -useb https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.ps1))) "packup" }
```
</code-block>
</code-group>

On Windows, PowerShell will need to run as administrator if the `--user` flag is
not used and the security policy must allow for running remote PowerShell
scripts. If needed, the following command will update the security policy for
the current user.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
