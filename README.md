# coba-vm

## Setup Minimal OpenCode + CLIProxyAPI

1) Buat file konfigurasi CLIProxyAPI menggunakan `cliproxy_config.yaml`:

	 - File: [cliproxy_config.yaml](cliproxy_config.yaml)

	 Content:

	 ```yaml
	 port: 8317
	 api-keys:
		 - "kodek"

	 openai-compatibility:
		 - name: "codex-zumy"
			 base-url: "https://codex.zumy.dev/v1"
			 api-key-entries:
				 - api-key: "kodek"
			 models:
				 - name: "gpt-5.3-codex"
					 alias: "gpt-5.3-codex"
	 ```

2) Jalankan CLIProxyAPI (dari folder instalasi `CLIProxyAPI`):

	 ```bash
	 cd ~/CLIProxyAPI
	 ./cliproxyapi -config config.yaml
	 # atau pakai file cliproxy_config.yaml yang dibuat di repo:
	 ./cliproxyapi -config ~/path/to/cliproxy_config.yaml
	 ```

	 Tunggu sampai output menunjukkan `1 OpenAI-compat`.

3) Wrapper OpenCode (opsional):

	 - File: [opencode-proxy.sh](opencode-proxy.sh)

	 Buat executable:

	 ```bash
	 chmod +x opencode-proxy.sh
	 ```

	 Contoh pemakaian:

	 ```bash
	 ./opencode-proxy.sh models openai
	 ./opencode-proxy.sh -m openai/gpt-5.3-codex
	 ```

Catatan: jika ingin permanen, tambahkan di `~/.bashrc`:

```bash
export OPENAI_API_KEY=kodek
export OPENAI_BASE_URL=http://localhost:8317/v1
```

3 hal penting:
- Config `openai-compatibility` di CLIProxyAPI
- Start server CLIProxyAPI
- Set `OPENAI_BASE_URL` ke `http://localhost:8317/v1` untuk OpenCode
# sync-codespace
