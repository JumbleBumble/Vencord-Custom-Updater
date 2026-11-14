
# Vencord Custom Updater (Windows)

**Keep Vencord up to date with a desktop shortcut while preserving your custom plugins.**

This project is for people running their own build of Vencord with **Discord Stable on Windows**.

The included setup script creates a desktop shortcut automatically, so you won't need to edit any scripts or manually enter file paths.

> **Already have Vencord source installed?** Skip to [Step 4](#step-4-download-the-updater-files).
>
> **Note:** Custom plugins are not officially supported by Vencord. Only install plugins from sources you trust, and keep backups. This updater does not back up or automatically update your custom plugins.

## Getting started (one-time setup)

### Step 1: Install the required tools

You'll need **Git**, **Node.js**, and **pnpm** to build Vencord from source. Follow [Vencord's official installation guide](https://docs.vencord.dev/installing/) for the recommended versions and setup.

- [Git downloads](https://git-scm.com/downloads)
- [Node.js downloads](https://nodejs.org/en/download)
- [pnpm installation guide](https://pnpm.io/installation)

Once installed, open **PowerShell** (search for it in the Windows Start menu) and run the following commands one at a time:

```powershell
git --version
node --version
pnpm --version
```

Each command should display a version number. If one isn't recognized, make sure it's installed correctly before continuing. You may also need to close and reopen PowerShell.

### Step 2: Clone Vencord's source code

Choose somewhere to keep your Vencord source folder, such as your Documents folder.

Open PowerShell and run:

```powershell
cd "$HOME\Documents"
git clone https://github.com/Vendicated/Vencord.git
cd Vencord
```

This downloads Vencord's source code into a new `Vencord` folder.

**Keep this folder**, as it's where your custom plugins and updater scripts will be stored.

**Important:** Clone Vencord using Git rather than downloading its source as a ZIP. The updater relies on Git to check for and download updates.

Next, install Vencord's dependencies:

```powershell
pnpm install --frozen-lockfile
```

Wait for the command to finish without errors before continuing.

For more information, refer to [Vencord's official installation guide](https://docs.vencord.dev/installing/).

### Step 3: Add your custom plugins

If you have custom plugins you'd like to use:

1. Open your `Vencord` folder in File Explorer.
2. Open the `src` folder.
3. Create a folder named `userplugins` if it doesn't already exist.
4. Place your custom plugin files inside `src\userplugins`.

For example:

```text
Vencord/
  src/
    userplugins/
      MyPlugin.ts
      AnotherPlugin/
        index.tsx
```

If you don't have any custom plugins yet, you can skip this step and add them later.

See [Vencord's custom plugin guide](https://docs.vencord.dev/installing/custom-plugins/) for more information on installing and creating custom plugins.

Only install plugins from sources you trust.

### Step 4: Download the updater files

1. Download **`Vencord-Updater.zip`** from this repository's Releases page, or download the individual files from the repository.
2. Extract the ZIP before using any of the scripts.
3. Copy the extracted files directly into your `Vencord` folder, alongside `package.json`, `pnpm-lock.yaml`, and `src`.

Your folder should look something like this:

```text
Vencord/
  src/
  package.json
  pnpm-lock.yaml
  Setup.cmd
  Setup.ps1
  Update-Vencord.ps1
  Build-Install-Run-Vencord.cmd           (optional)
  Build-Install-Run-Vencord.ps1           (optional)
```

**Make sure the files are placed in the Vencord root folder**, not inside `src`, `userplugins`, or a separate updater subfolder.

### Step 5: Run Setup.cmd

Open your `Vencord` folder in File Explorer and double-click **`Setup.cmd`**.

The setup script checks that everything is in the correct location and creates an **Update Vencord** shortcut on your desktop.

It does not install Git, Node.js, pnpm, or Vencord itself. Those need to be installed beforehand.

Keep the updater files in your Vencord folder. If you move the folder later, run `Setup.cmd` again to update the shortcut.

### Step 6: Build and install your custom plugins (first-time installation)

Once you've added your plugins to `src\userplugins`, double-click **`Build-Install-Run-Vencord.cmd`** inside your Vencord folder.

This script will:

1. Close Discord Stable, including any remaining background processes if necessary.
2. Build Vencord with your custom plugins using `pnpm build --dev`.
3. Install the build into Discord Stable.
4. Reopen Discord once installation finishes.

This script **does not check for or download Vencord updates**. It builds and installs whatever source code is currently in your Vencord folder.

You can also use it whenever you add, remove, or edit a custom plugin and need to apply the changes.

If you're setting up Vencord without custom plugins, you can use the desktop **Update Vencord** shortcut for the initial build and installation instead. On its first run, the updater normally builds and installs the current checkout.

After Discord opens, check **Vencord Settings → Plugins** and enable your custom plugins if needed.

## Everyday use: which file should I run?

### Recommended: Use the Update Vencord shortcut to launch Discord

I recommend using the **Update Vencord** desktop shortcut instead of your normal Discord shortcut when opening Discord for the first time after starting your PC.

This way, Vencord gets checked for updates whenever you're starting a new Discord session.

When you open the shortcut, it will:

1. **Check for updates:** See if any new Vencord commits are available.
2. **Update if needed:** Download the latest changes, rebuild Vencord with your custom plugins, and install the updated build.
3. **Launch Discord:** Open Discord Stable once the update check or installation finishes.

If Vencord is already up to date, the script skips the build and opens Discord normally.

You can still open Discord the usual way whenever you want. Using the updater shortcut is simply a convenient way to keep your Vencord installation current without checking manually.

### Which file should I use?

| What you want to do | What to double-click |
| --- | --- |
| **Launch Discord and check for Vencord updates (recommended)** | **Update Vencord** (desktop shortcut) |
| **Add or edit a custom plugin** and apply your changes | **Build-Install-Run-Vencord.cmd** (in your Vencord folder) |
| **Re-create the desktop shortcut** | **Setup.cmd** |

### Important things to know

**Custom plugin changes:** The desktop updater checks Git for upstream Vencord updates and keeps track of which commit was last installed. If you only add or edit a custom plugin without any Vencord updates being available, it may skip the build.

To apply changes to your custom plugins, use **`Build-Install-Run-Vencord.cmd`** instead.

**Keeping your plugins safe:** The updater does not intentionally delete or reset your custom plugin files. However, upstream updates can occasionally conflict with custom files, and Vencord changes may cause some plugins to stop working.

It's recommended to **back up your `src\userplugins` folder** before major updates.

## What the files do

- **`Setup.cmd`** — Runs the initial setup and creates your desktop shortcut.
- **`Setup.ps1`** — Handles shortcut creation and folder validation. Used automatically by `Setup.cmd`.
- **`Update-Vencord.ps1`** — Checks for upstream Vencord updates, safely updates the source, rebuilds and installs Vencord when needed, and launches Discord.
- **`Build-Install-Run-Vencord.cmd`** *(optional)* — Double-click this to rebuild and install your current Vencord source and custom plugins.
- **`Build-Install-Run-Vencord.ps1`** *(optional)* — Handles the build, installation, and Discord restart. Used automatically by its `.cmd` launcher.

## Common problems

**Git, pnpm, or Node.js isn't recognized**

Make sure the required tools from Step 1 are installed. Close and reopen PowerShell after installing them.

**Setup says it can't find Vencord**

Make sure the scripts are directly inside your Git-cloned Vencord folder, next to `package.json`. Also make sure you've extracted the ZIP rather than trying to run the files from inside it.

**The desktop shortcut stopped working after moving Vencord**

Run `Setup.cmd` again from the new Vencord folder location to recreate the shortcut.

**The updater reports local changes or local commits**

The updater stops when it detects tracked file changes or local commits that could prevent a safe update.

If you've modified tracked files, commit or stash those changes before trying again.

If your branch contains its own commits, the updater won't automatically fast-forward it. You'll need to handle those changes manually or use a clean checkout.

This is intentional to avoid overwriting your work.

**Discord won't close**

Try closing Discord manually from the Windows system tray, then run the updater again.

Both the updater and the optional build helper attempt to close Discord Stable gracefully. If Discord remains running in the background, they can force-close its remaining Stable processes before installation.

**I added a plugin, but it isn't showing up**

Run `Build-Install-Run-Vencord.cmd` to rebuild Vencord with your changes.

Once Discord opens, check **Vencord Settings → Plugins** to see if the plugin needs to be enabled.

If the build fails, check [Vencord's custom plugin guide](https://docs.vencord.dev/installing/custom-plugins/) to make sure your plugin is installed correctly.

**The build or injector fails**

Check the error message displayed in the command window.

Make sure:

- You're using a valid Vencord source checkout.
- You've installed dependencies using `pnpm install --frozen-lockfile`.
- Discord Stable is installed.
- Git, Node.js, and pnpm are available in PowerShell.

If the error is related to a custom plugin, try checking that plugin's code or compatibility with your current Vencord version.

**I use Discord PTB, Canary, or Vesktop**

These scripts currently support **Discord Stable on Windows** only.

## Notes and safety

- Setup only creates a local desktop shortcut. It does not download or install Vencord or its prerequisites.
- The updater does not run automatically in the background. Updates are only checked when you launch the shortcut.
- The updater does not intentionally delete, reset, or clean your Vencord repository.
- Custom plugins are preserved during normal updates, but compatibility with future Vencord versions is not guaranteed.
- The updater does not back up or update custom plugins individually.
- Running custom plugins or PowerShell scripts executes code on your computer. Review scripts and only use plugins from sources you trust.
- The `.cmd` launchers use `-ExecutionPolicy Bypass` for their PowerShell process only. They do not change your system-wide execution policy.
- Vencord does not officially support custom plugins or custom installations. This updater is an independent community utility and is not affiliated with the Vencord project.

### Official references

- [Vencord — Installing from Source](https://docs.vencord.dev/installing/)
- [Vencord — Installing Custom Plugins](https://docs.vencord.dev/installing/custom-plugins/)