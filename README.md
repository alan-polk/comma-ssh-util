# comma-ssh-key

Restore or regenerate the GitHub SSH key on a comma device, in one command.

## Why this exists

On AGNOS, `~/.ssh` lives on a tmpfs overlay — it's wiped on every reboot.
A full reflash wipes `/data` too, which is the only thing that survives a
reboot. So there are two failure modes, and this script handles both:

- **Reboot** (home wiped, `/data` survives): restores the key from a
  `/data` mirror. No GitHub changes needed.
- **Reflash** (home *and* `/data` wiped): generates a new key and prints
  the one step that's unavoidably yours — adding it to GitHub.

It does not touch `/persist`, does not remount the system partition
read-write, and never deletes an existing key unless you pass `--force`.

## Use

```sh
git clone https://github.com/<you>/comma-ssh-key.git
bash comma-ssh-key/comma-ssh-key.sh
```

Clone over HTTPS, not SSH — if the device has no key at all (post-reflash),
an SSH clone can't work yet, and HTTPS needs no auth. That's also why this
repo is public: it carries no secrets, only the script, so there's no
bootstrap problem.

Run it again any time you're not sure the key is in place; it's a no-op if
one already exists.

```sh
bash comma-ssh-key/comma-ssh-key.sh --force   # replace the current key
```
