GitHub SSH is manual because the application repo is private.

1. Generate a key on the Pi if needed:
   ssh-keygen -t ed25519 -C "cam02"

2. Print the public key:
   cat ~/.ssh/id_ed25519.pub

3. Add it in GitHub:
   Settings -> SSH and GPG keys -> New SSH key

4. Test access:
   ssh -T git@github.com

Only continue after the SSH test succeeds.
