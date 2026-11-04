<!-- Fluxo README -->

<div align="center">

  <h1>💧 Fluxo</h1>
  <p><strong>A simple, beautiful way to stay on top of your personal finances.</strong></p>

  <p>
    <img src="img/img1.png" alt="Fluxo app screenshot" width="850">
  </p>

  <p>
    <img src="https://img.shields.io/badge/status-in%20development-8b5cf6?style=for-the-badge" alt="Project status">
    <img src="https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white" alt="HTML5">
    <img src="https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white" alt="CSS3">
    <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black" alt="JavaScript">
    <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
    <img src="https://img.shields.io/badge/No%20frameworks-222222?style=for-the-badge" alt="No frameworks">
  </p>

  <p>
    <a href="#-features">Features</a> ·
    <a href="#-open-fluxo">Open Fluxo</a> ·
    <a href="#-docker-installation">Docker installation</a> ·
    <a href="#-tech-stack">Tech stack</a> ·
    <a href="#-data-and-privacy">Data & privacy</a>
  </p>

</div>

---

## ✨ About

**Fluxo** is a lightweight personal finance tracker built with vanilla HTML, CSS, and JavaScript. It helps you organize your income and expenses, keep an eye on your budget, and understand where your money goes — all through a clean, responsive interface.

No frameworks, no complicated setup. Just open the app and take control of your finances.

## 🚀 Features

- **Dashboard** — Get an overview of your total balance, income, and expenses.
- **Transactions** — Add, edit, delete, and search through financial records.
- **Categories** — Organize transactions with built-in or custom categories.
- **Budgets** — Set monthly spending limits and get warnings when you approach or exceed them.
- **Recurring transactions** — Schedule weekly, monthly, or yearly entries.
- **Visual reports** — Explore spending breakdowns and income/expense charts.
- **Personalization** — Customize accent colors, wallpapers, and animations.
- **Language options** — Switch the app's display language.
- **Local accounts** — Create an account and keep separate data in your browser.

## 🌐 Open Fluxo

Fluxo is available as a web app. Open it directly in your browser:

<p align="center">
  <a href="https://sigmadev21.github.io/fluxo/">
    <img src="https://img.shields.io/badge/🚀%20Open%20Fluxo-8b5cf6?style=for-the-badge" alt="Open Fluxo">
  </a>
</p>

## 🐳 Docker installation

Run Fluxo locally in a Docker container. The installation scripts can install or guide you through setting up Docker, download the latest Fluxo source, build the image, and start the container.

### Requirements

- **Linux / macOS:** Docker Engine or Docker Desktop, plus `curl`. Git is optional.
- **Windows:** Docker Desktop with its WSL 2 backend enabled, and PowerShell.
- An available port on your computer (the default is `8080` for HTTP).

### Quick install

**Linux / macOS**

Run this command in a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/sigmadev21/fluxo/main/install.sh | bash
```

**Windows (PowerShell)**

Run these commands in PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/sigmadev21/fluxo/main/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

When the installer finishes, open **http://localhost:8080**.

> **Windows note:** If Docker Desktop was just installed, open it, complete its first-run setup, enable WSL 2 if prompted, and then run the installer again.

### Choose a different port

The default HTTP port is `8080`. If it is already in use, choose another one:

```bash
# Linux / macOS
./install.sh --port 3000
```

```powershell
# Windows
.\install.ps1 -Port 3000
```

### Enable HTTPS for other devices

To use Fluxo from a phone or another computer on your local network, install it with HTTPS:

```bash
# Linux / macOS
./install.sh --https
```

```powershell
# Windows
.\install.ps1 -Https
```

The default HTTPS address is **https://localhost:8443**. The installer creates a self-signed certificate, so your browser will show a certificate warning that you must review and accept before opening the app.

HTTPS matters because browser features used for sign-in require a secure context. `localhost` is treated as secure, but a plain HTTP address on your local network usually is not.

### Manual Docker setup

If you prefer to manage the container yourself, clone the repository and use Docker Compose:

```bash
git clone https://github.com/sigmadev21/fluxo.git
cd fluxo
docker compose up -d --build
```

Fluxo will be available at **http://localhost:8080**. To use another port:

```bash
FLUXO_PORT=3000 docker compose up -d --build
```

You can also build and run the image directly:

```bash
docker build -t fluxo .
docker run -d --name fluxo --restart unless-stopped -p 8080:80 fluxo
```

### Updating Fluxo

The update scripts download the latest project files, rebuild the Docker image, and recreate the container. They preserve the currently configured HTTP/HTTPS mode and port.

**Linux / macOS**

From the Fluxo installation directory:

```bash
./update.sh
```

Or run the updater directly:

```bash
curl -fsSL https://raw.githubusercontent.com/sigmadev21/fluxo/main/update.sh | bash
```

**Windows (PowerShell)**

From the Fluxo installation directory:

```powershell
.\update.ps1
```

### Uninstalling Fluxo

Uninstallation removes the Fluxo container and Docker image. It does **not** uninstall Docker or delete your browser data.

**Linux / macOS**

```bash
./uninstall.sh
```

To also delete the downloaded Fluxo folder (including any generated HTTPS certificates):

```bash
./uninstall.sh --purge
```

**Windows (PowerShell)**

```powershell
.\uninstall.ps1
```

To also delete the downloaded Fluxo folder:

```powershell
.\uninstall.ps1 -Purge
```

> **Your data stays in your browser.** Fluxo stores accounts and transactions in the browser's Local Storage, not in the Docker container. Updating or uninstalling the container does not remove that data. To erase it, clear this website's data in your browser settings.

### Useful Docker commands

```bash
docker ps --filter name=fluxo   # Check whether Fluxo is running
docker logs fluxo               # View container logs
docker stop fluxo               # Stop Fluxo
docker start fluxo              # Start Fluxo again
```

### Troubleshooting

| Problem | What to do |
| --- | --- |
| Port is already in use | Re-run the installer with another port, such as `--port 3000` or `-Port 3000`. |
| Docker daemon is not responding | Start Docker Engine or open Docker Desktop, then retry. |
| Permission denied on Linux | Make sure your user has permission to access Docker. You may need to log out and back in after being added to the `docker` group. |
| Sign-in does not work from another device | Use HTTPS. Plain HTTP is only a secure context on `localhost`. |
| Windows asks to enable WSL 2 | Enable WSL 2, restart if requested, open Docker Desktop, and run the installer again. |

## 🧰 Tech stack

| Technology | Purpose |
| --- | --- |
| HTML5 | App structure |
| CSS3 | Styling, responsive layout, animations, and visual effects |
| Vanilla JavaScript | App logic, interactions, and data handling |
| Local Storage | Saving data in the browser |
| Docker + Nginx | Optional local hosting |

## 🔐 Data and privacy

Fluxo currently stores account information and financial data locally in your browser using **Local Storage**.

- Your data stays in the browser where you use the app.
- Data is not automatically synchronized between devices or browsers.
- Clearing the browser's site data may erase your Fluxo information.
- The Docker container only serves the app; it does not store your accounts or transactions.

**Tip:** Keep your own backup of important information.

## 🗺️ Project structure

```text
fluxo/
├── img/
│   └── img1.png
├── .dockerignore
├── Dockerfile
├── docker-compose.yml
├── index.html
├── install.sh
├── install.ps1
├── nginx.conf
├── nginx-ssl.conf
├── uninstall.sh
├── uninstall.ps1
├── update.sh
├── update.ps1
└── README.md
```

## 🤝 Contributing

Suggestions, bug reports, and contributions are welcome!

If you find a bug or have an idea to improve Fluxo, feel free to open an issue or submit a pull request.

## 📄 License

No license has been specified for this project yet.

---

<div align="center">
  Made with 💜 by <a href="https://github.com/sigmadev21">sigmadev21</a>
</div>
