# syntax=docker/dockerfile:1
ARG UBUNTU_TAG=24.04
FROM docker.io/ubuntu:${UBUNTU_TAG}

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV SHELL=/bin/bash

# =============================================================================
# 1. Core System Dependencies
# =============================================================================
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    build-essential \
    unzip \
    locales \
    ripgrep \
    fzf \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Generate locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# fd-find symlink (telescope looks for 'fd', Ubuntu packages it as 'fdfind')
RUN ln -s $(which fdfind) /usr/local/bin/fd

# =============================================================================
# 2. Go (latest release)
# =============================================================================
RUN GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1) \
    && curl -LO https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf ${GO_VERSION}.linux-amd64.tar.gz \
    && rm ${GO_VERSION}.linux-amd64.tar.gz

# =============================================================================
# 2.5 Environment & PATH (needed before language servers are installed)
# =============================================================================
ENV PATH="/root/go/bin:/usr/local/go/bin:/opt/nvim-linux-x86_64/bin:/root/.opencode/bin:/root/.local/bin:/usr/local/bin:${PATH}"
ENV HOME=/root

# =============================================================================
# 3. Node.js (NodeSource 22.x)
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update && apt-get upgrade -y && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g tree-sitter-cli

# =============================================================================
# 3.5 Language Servers (for LSP support in NvChad)
# =============================================================================
RUN go install golang.org/x/tools/gopls@latest \
    && npm install -g typescript-language-server typescript \
    && npm install -g pyright \
    && npm install -g @tailwindcss/language-server

# =============================================================================
# 4. Neovim (latest official release, built with LuaJIT)
# =============================================================================
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    && tar -C /opt -xzf nvim-linux-x86_64.tar.gz \
    && rm nvim-linux-x86_64.tar.gz

# =============================================================================
# 5. Lazygit
# =============================================================================
RUN LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') \
    && curl -LO https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_x86_64.tar.gz \
    && tar -xzf lazygit_*_Linux_x86_64.tar.gz -C /tmp \
    && mv /tmp/lazygit /usr/local/bin/ \
    && rm lazygit_*_Linux_x86_64.tar.gz

# =============================================================================
# 6. Zellij (pre-built musl binary)
# =============================================================================
RUN ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') \
    && curl -LO https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf zellij-x86_64-unknown-linux-musl.tar.gz -C /usr/local/bin \
    && rm zellij-x86_64-unknown-linux-musl.tar.gz \
    && chmod +x /usr/local/bin/zellij

# =============================================================================
# 7. OpenCode (official curl installer)
# =============================================================================
RUN curl -fsSL https://opencode.ai/install | bash

# =============================================================================
# 9. NvChad Configuration
# =============================================================================
# Backup existing nvim config (if any) and clone starter
RUN mv /root/.config/nvim /root/.config/nvim.bak 2>/dev/null || true \
    && git clone https://github.com/NvChad/starter /root/.config/nvim \
    && rm -rf /root/.config/nvim/.git

# Use OSC52 for clipboard integration (works in containers, ssh, tmux, zellij)
RUN cat >> /root/.config/nvim/lua/options.lua << 'CLIPBOARDEOF'

-- OSC52 clipboard (works through any terminal, no external tools needed)
vim.opt.clipboard = "unnamedplus"
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}

-- Required for opencode.nvim auto-reload of edited buffers
vim.o.autoread = true
CLIPBOARDEOF

# Add opencode.nvim plugin (connects to opencode running in the zellij pane)
RUN cat > /root/.config/nvim/lua/plugins/opencode.lua << 'OPENCODEEOF'
return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    config = function()
      vim.g.opencode_opts = {}

      -- Keymaps (leader-o prefix to avoid conflicts)
      vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask() end,           { desc = "Ask opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>os", function() require("opencode").select() end,         { desc = "Select opencode action" })
      vim.keymap.set({ "n", "t" }, "<leader>ot", function() require("opencode").toggle() end,       { desc = "Toggle opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>oo", function() return require("opencode").operator() end, { desc = "Opencode operator", expr = true })
    end,
  },
}
OPENCODEEOF

# Language-specific NvChad plugin configurations
RUN cat > /root/.config/nvim/lua/plugins/treesitter.lua << 'TSEOF'
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "go", "python", "javascript", "typescript", "tsx", "lua", "vim", "vimdoc", "markdown" },
    },
  },
}
TSEOF

RUN cat > /root/.config/nvim/lua/plugins/lspconfig.lua << 'LSPEOF'
return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      local lspconfig = require("lspconfig")
      local nvlsp = require("nvchad.configs.lspconfig")
      local servers = { "gopls", "pyright", "ts_ls" }
      for _, lsp in ipairs(servers) do
        lspconfig[lsp].setup {
          on_attach = nvlsp.on_attach,
          on_init = nvlsp.on_init,
          capabilities = nvlsp.capabilities,
        }
      end
    end,
  },
}
LSPEOF

# Pre-install all NvChad plugins (Tree-sitter parsers are auto-installed
# via ensure_installed on first file open by nvim-treesitter)
RUN nvim --headless "+Lazy! sync" +qa || true

# =============================================================================
# 10. Zellij Layout
# =============================================================================
RUN mkdir -p /root/.config/zellij/layouts
COPY zellij-layout.kdl /root/.config/zellij/layouts/dev.kdl

# =============================================================================
# 11. Final Setup
# =============================================================================
WORKDIR /workspace

# Declare volumes for project code and opencode data
VOLUME ["/workspace", "/root/.config/opencode", "/root/.local/share/opencode", "/root/.local/state/opencode", "/root/.cache/opencode"]

# Default: launch zellij with the dev layout
CMD ["zellij", "--layout", "/root/.config/zellij/layouts/dev.kdl"]
