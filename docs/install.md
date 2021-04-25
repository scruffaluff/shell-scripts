# Installation

Shell Scripts provides Bash and PowerShell install scripts to download any
collection of scripts from the repository. The following commands show the help
information for the scripts.

<code-group>
<code-block title="Linux" active>
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- --help
```
</code-block>

<code-block title="MacOS">
```bash
curl -LSfs https://raw.githubusercontent.com/wolfgangwazzlestrauss/shell-scripts/master/install.sh | bash -s -- --help
```
</code-block>
</code-group>

On Windows, PowerShell will need to run as administrator and the security policy
must allow for running remote PowerShell scripts. The following command will
update the security policy, if needed.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```
