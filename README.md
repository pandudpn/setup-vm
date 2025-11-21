# Terminal Setup Script

Script otomatis untuk setup development environment lengkap dengan tmux, zsh, ranger, Docker, dan berbagai CLI tools.

## Fitur

- ✅ Membuat user development tanpa password (lebih aman, bisa set password nanti)
- ✅ Install dan konfigurasi Zsh dengan Oh My Zsh
- ✅ Install tmux dengan konfigurasi optimal
- ✅ Install ranger file manager dengan preview dependencies
- ✅ Install Docker dan Docker Compose dengan non-root access
- ✅ Install CLI tools: fzf, ripgrep, ncdu, htop, neofetch, bat
- ✅ Konfigurasi otomatis dengan aliases dan plugins
- ✅ Error handling yang robust (satu kegagalan tidak menghentikan instalasi)

## Requirements

- Debian/Ubuntu-based Linux distribution
- Root privileges (jalankan dengan sudo)
- Internet connection

## Cara Penggunaan

### 1. Setup Environment Baru

**Sebelum menjalankan script**, edit `setup-shell.sh` dan update konfigurasi SSH key:

```bash
# Edit file setup-shell.sh
nano setup-shell.sh

# Cari dan update baris berikut:
SSH_PUBLIC_KEY_URL="https://github.com/YOUR_GITHUB_USERNAME.keys"
# Ganti YOUR_GITHUB_USERNAME dengan username GitHub Anda
# Contoh: SSH_PUBLIC_KEY_URL="https://github.com/pandudpn.keys"

# Atau gunakan raw URL dari repository Anda:
# SSH_PUBLIC_KEY_URL="https://raw.githubusercontent.com/username/dotfiles/main/id_ed25519.pub"

# Jika tidak ingin setup SSH key, set:
SETUP_SSH_KEY="false"
```

Kemudian jalankan script:

```bash
sudo ./setup-shell.sh
```

Script akan:
1. Meminta username (default: deploy)
2. Membuat user tanpa password
3. Install semua packages dan tools
4. Konfigurasi environment
5. Download dan setup SSH public key dari GitHub
6. Set zsh sebagai default shell

### 2. Reset Password User (Jika Diperlukan)

Jika Anda perlu reset password atau disable password untuk user yang sudah ada:

```bash
# Set password baru
sudo ./reset-user-password.sh <username>

# Atau disable password (recommended)
sudo ./reset-user-password.sh <username> --disable
```

**Contoh:**
```bash
# Disable password untuk user 'deploy'
sudo ./reset-user-password.sh deploy --disable

# Set password baru untuk user 'deploy'
sudo ./reset-user-password.sh deploy
```

### 3. Delete User (Jika Diperlukan)

Jika Anda perlu menghapus user beserta semua file dan konfigurasinya:

```bash
# Delete user dengan konfirmasi
sudo ./delete-user.sh <username>

# Delete user tanpa konfirmasi (force)
sudo ./delete-user.sh <username> --force
```

**Contoh:**
```bash
# Delete user 'deploy' dengan konfirmasi
sudo ./delete-user.sh deploy

# Delete user 'deploy' tanpa konfirmasi
sudo ./delete-user.sh deploy --force
```

**Fitur delete-user.sh:**
- ✅ Konfirmasi ganda untuk keamanan (kecuali pakai --force)
- ✅ Menampilkan informasi user sebelum delete
- ✅ Terminate semua proses user secara otomatis
- ✅ Hapus home directory dan semua file
- ✅ Cleanup file temporary dan cron jobs
- ✅ Proteksi: tidak bisa delete system user (UID < 1000)
- ✅ Proteksi: tidak bisa delete user yang sedang login

## Setelah Instalasi

1. **(Opsional)** Set password jika diperlukan:
   ```bash
   sudo passwd <username>
   ```

2. Logout dan login kembali agar perubahan group (docker, sudo) berlaku

3. Switch ke user baru:
   ```bash
   su - <username>
   ```

4. Mulai gunakan environment Anda!

## User Tanpa Password

Script ini membuat user **tanpa password** secara default karena:

- ✅ Lebih aman dari masalah special characters
- ✅ Bisa switch dari root tanpa password: `su - username`
- ✅ Bisa set password nanti jika diperlukan
- ✅ Sudah ada di sudo group untuk administrative tasks

Jika Anda ingin set password nanti, gunakan:
```bash
sudo passwd <username>
```

## SSH Key Setup

Script ini otomatis download dan setup SSH public key dari GitHub untuk user baru:

### Cara Kerja:

1. **GitHub Keys Endpoint** (Recommended):
   ```bash
   SSH_PUBLIC_KEY_URL="https://github.com/username.keys"
   ```
   GitHub menyediakan endpoint ini yang berisi semua public keys dari akun Anda.

2. **Raw File dari Repository**:
   ```bash
   SSH_PUBLIC_KEY_URL="https://raw.githubusercontent.com/username/dotfiles/main/id_ed25519.pub"
   ```
   Jika Anda menyimpan public key di repository.

### Fitur SSH Key Setup:

- ✅ Download otomatis dari URL yang dikonfigurasi
- ✅ Validasi format SSH key
- ✅ Backup authorized_keys yang sudah ada
- ✅ Set permissions yang benar (700 untuk .ssh, 600 untuk authorized_keys)
- ✅ Menampilkan fingerprint key yang terinstall
- ✅ Support multiple keys (jika GitHub endpoint memiliki beberapa keys)

### Disable SSH Key Setup:

Jika tidak ingin setup SSH key, edit script dan set:
```bash
SETUP_SSH_KEY="false"
```

### Test SSH Key URL:

Sebelum menjalankan setup, Anda bisa test apakah URL SSH key Anda valid:

```bash
./test-ssh-key-url.sh "https://github.com/username.keys"
```

Script ini akan:
- ✅ Cek apakah URL accessible
- ✅ Validasi format SSH key
- ✅ Tampilkan jumlah keys yang ditemukan
- ✅ Tampilkan fingerprint setiap key

## Troubleshooting

### Tidak bisa login karena password dengan special characters

Gunakan script reset password:
```bash
sudo ./reset-user-password.sh <username> --disable
```

Kemudian switch ke user:
```bash
su - <username>
```

### Docker permission denied

Logout dan login kembali agar perubahan docker group berlaku, atau jalankan:
```bash
newgrp docker
```

## File Konfigurasi

Script membuat file-file berikut:

- `~/.zshrc` - Konfigurasi Zsh dengan plugins dan aliases
- `~/.tmux.conf` - Konfigurasi tmux
- `~/.config/ranger/` - Konfigurasi ranger
- `~/.oh-my-zsh/` - Oh My Zsh framework
- `~/.zsh/` - Zsh plugins (autosuggestions, syntax-highlighting)
- `~/.ssh/authorized_keys` - SSH public keys (jika SETUP_SSH_KEY=true)

## Helper Scripts

Repository ini menyediakan beberapa helper scripts:

### 1. `setup-shell.sh`
Script utama untuk setup environment lengkap.

### 2. `reset-user-password.sh`
Reset atau disable password untuk user.
```bash
sudo ./reset-user-password.sh <username>          # Set password baru
sudo ./reset-user-password.sh <username> --disable # Disable password
```

### 3. `delete-user.sh`
Hapus user beserta semua file dan konfigurasi.
```bash
sudo ./delete-user.sh <username>         # Dengan konfirmasi
sudo ./delete-user.sh <username> --force # Tanpa konfirmasi
```

### 4. `test-ssh-key-url.sh`
Test validitas SSH key URL sebelum menjalankan setup.
```bash
./test-ssh-key-url.sh "https://github.com/username.keys"
```

### 5. `config.example.sh`
Contoh konfigurasi yang bisa di-copy ke setup-shell.sh.

### 6. `customize-theme.sh`
Customize zsh theme dan tampilan terminal.
```bash
./customize-theme.sh              # Interactive mode
./customize-theme.sh agnoster     # Apply specific theme
./customize-theme.sh random       # Random theme on each startup
./customize-theme.sh --list       # Show available themes
```

## Customization

### Mengubah Zsh Theme

Script ini menggunakan theme **agnoster** secara default (powerline-style dengan git info). Anda bisa mengubahnya dengan:

```bash
./customize-theme.sh
```

**Theme Populer:**
- `robbyrussell` - Simple dan cepat (Oh My Zsh default)
- `agnoster` - Powerline-style dengan git info (script default)
- `af-magic` - Colorful dengan git status
- `bira` - Two-line prompt dengan waktu
- `ys` - Git-focused dengan exit codes
- `random` - Random theme setiap startup

**Quick Change:**
```bash
./customize-theme.sh agnoster    # Apply agnoster theme
./customize-theme.sh random      # Random theme
./customize-theme.sh --list      # Lihat semua theme
```

### Custom Aliases

Script sudah include banyak aliases berguna:

**Navigation:**
- `ll`, `la`, `l` - List files dengan berbagai opsi
- `..`, `...`, `....` - Navigate up directories
- `c` - Clear screen

**Docker:**
- `dps`, `dpsa` - Docker ps / ps -a
- `di` - Docker images
- `dex` - Docker exec -it
- `dlog` - Docker logs -f

**Git:**
- `gs`, `ga`, `gc` - Git status/add/commit
- `gp`, `gl` - Git push/pull
- `glog` - Git log (pretty format)

**System:**
- `update` - Update system packages
- `install` - Install package
- `meminfo` - Memory info
- `diskinfo` - Disk usage

Ketik `help-aliases` di terminal untuk melihat semua aliases.

### Neofetch Customization

Neofetch config sudah di-customize untuk tampilan optimal. File config ada di:
```
~/.config/neofetch/config.conf
```

Edit file tersebut untuk customize informasi yang ditampilkan.

## Testing

Script ini dilengkapi dengan 80+ property-based tests menggunakan Bats:

```bash
# Jalankan semua tests
bats tests/

# Jalankan test spesifik
bats tests/property_user_creation.bats
```

## Lisensi

MIT License

