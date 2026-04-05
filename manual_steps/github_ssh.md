Run these steps in another terminal on the Pi.

1. Generate an SSH key if you do not already have one:

   ssh-keygen -t ed25519 -C "camXX"

   Press Enter for all prompts (no passphrase for headless devices is fine).

2. Print the public key:

   cat ~/.ssh/id_ed25519.pub

3. Add the key to GitHub:
   GitHub -> Settings -> SSH and GPG keys -> New SSH key

   Suggested title:
   pi-deploy-key-camXX

4. Test the connection:

   ssh -T git@github.com

   If you see a host verification prompt, type:
   yes

5. Confirm you see a successful authentication message before returning here.
