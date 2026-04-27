## 1. Install Git

First, check if Git is already installed on your system by opening your terminal and typing:

`git --version`

If Git is not installed, use the appropriate command for your distribution:

### Ubuntu / Debian / Linux Mint

`sudo apt update`
`sudo apt install git`

---

## 2. Configure Your Git Identity

### Set your username:

`git config --global user.name "Your Name"`

### Set your email:

`git config --global user.email "your_email@example.com"`

### Verify settings:

`git config --list`

---

## 3. Generate an SSH Key

Step 1: Generate the key

Run the following command (replace the email with your GitHub email):

`ssh-keygen -t ed25519 -C "your_email@example.com"`

* When prompted to "Enter a file in which to save the key," press **Enter** to use the default location.
* You may enter a passphrase for extra security or leave it blank.

### Step 2: Start the ssh-agent

`eval "$(ssh-agent -s)"`

### Step 3: Add your key to the agent

`ssh-add ~/.ssh/id_ed25519`

---

## 4. Connect the SSH Key to GitHub

Now you must tell GitHub about your new key.

1. **Copy the public key to your clipboard:**
   `cat ~/.ssh/id_ed25519.pub`
   *(Highlight and copy the text that appears in your terminal window.)*
2. **Add to your GitHub Account:**
   * Log in to [GitHub](https://github.com).
   * Click your profile photo in the top-right → **Settings** .
   * On the left sidebar, click **SSH and GPG keys** .
   * Click the green **New SSH key** button.
   * Give it a **Title** (e.g., "Linux Desktop") and paste your key into the **Key** box.
   * Click **Add SSH key** .

---

## 5. Test Your Connection

Verify that everything is linked correctly by attempting to "handshake" with GitHub:

`ssh -T git@github.com`

* If you see a warning about the authenticity of the host, type **yes** and press **Enter** .
* If successful, you will see: *"Hi [YourUsername]! You've successfully authenticated..."*

### Execution

The code used is below, I was assisted by AI in the writing of this

![](assets/20260414_165025_image.png)

Below is a successful run through of the code to create a vm named ub-test.

![](assets/20260422_182051_image.png)
