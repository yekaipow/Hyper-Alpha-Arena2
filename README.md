# <img width="40" height="40" alt="logo_app" src="https://github.com/user-attachments/assets/911ba846-a08b-4e3e-b119-ec1e78347288" style="vertical-align: middle;" /> Hyper Alpha Arena

> An open-source AI-powered cryptocurrency trading platform for autonomous trading with Large Language Models. Deploy AI trading strategies with both paper trading simulation and real perpetual contract trading on Hyperliquid DEX.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub stars](https://img.shields.io/github/stars/HammerGPT/Hyper-Alpha-Arena)](https://github.com/HammerGPT/Hyper-Alpha-Arena/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/HammerGPT/Hyper-Alpha-Arena)](https://github.com/HammerGPT/Hyper-Alpha-Arena/network)
[![Community](https://img.shields.io/badge/Telegram-Community-blue?logo=telegram)](https://t.me/+RqxjT7Gttm9hOGEx)

## 🔥 Start Trading Now - Up to 30% Fee Discount

Ready to put your AI trading strategies to work? Get started with these top exchanges:

### 🚀 **Hyperliquid** - Decentralized Perpetual Exchange
- **No KYC Required** | **Low Fees** | **High Performance**
- Direct integration with Hyper Alpha Arena
- [**Open Futures Trading →**](https://app.hyperliquid.xyz/join/HYPERSVIP)

### 💰 **Binance** - World's Largest Exchange
- **30% Fee Discount** | **High Liquidity** | **Advanced Tools**
- [**Register with 30% Discount →**](https://accounts.maxweb.red/register?ref=HYPERVIP)

### ⚡ **Aster DEX** - Binance-Compatible DEX
- **Lower Fees** | **Multi-chain Support** | **API Wallet Security**
- [**Register Now →**](https://www.asterdex.com/zh-CN/referral/2b5924)

---

## Overview

Hyper Alpha Arena is a production-ready AI trading platform where Large Language Models (LLMs) autonomously execute cryptocurrency trading strategies. Inspired by [nof1 Alpha Arena](https://nof1.ai), this platform enables AI models like GPT-5, Claude, and Deepseek to make intelligent trading decisions based on real-time market data and execute trades automatically.

**Official Website:** https://www.akooi.com/

**Trading Modes:**
- **Hyperliquid Testnet (Paper Trading)**: Risk-free testing with real market mechanics, free test funds, and actual order book - a superior paper trading experience
- **Hyperliquid Mainnet**: Live trading on decentralized perpetual exchange with 1-50x leverage support (real capital at risk)

## Features

### Core Trading Features
- **Multi-Model LLM Support**: OpenAI API compatible models (GPT-5, Claude, Deepseek, etc.)
- **Multi-Wallet Architecture**: Each AI Trader can configure separate wallets for Testnet and Mainnet
- **Global Trading Mode**: Centralized environment switch affecting all AI Traders simultaneously
- **AI Prompt Generator**: Interactive chat interface for generating optimized trading strategy prompts
  - Natural language conversation to define trading goals and risk preferences
  - Automatic generation of structured prompts with technical indicators
  - Conversation history management with title editing
  - One-click application to AI Trader configurations
- **Prompt Template Management**:
  - Customizable AI trading prompts with visual editor
  - Account-specific prompt binding system with Hyperliquid-specific templates
  - Default, Pro, and Hyperliquid templates with leverage education
  - Automatic fallback to default template for unbound accounts
- **Technical Analysis Integration**: 11 built-in technical indicators
  - Trend: SMA, EMA, MACD
  - Momentum: RSI, Stochastic Oscillator
  - Volatility: Bollinger Bands, ATR
  - Volume: OBV, VWAP
  - Support/Resistance: Pivot Points, Fibonacci Retracement
- **Real-time Market Data**: Live cryptocurrency price feeds from multiple exchanges via ccxt
- **AI Trader Management**: Create and manage multiple AI trading agents with independent configurations

### Hyperliquid Trading Features
- **Perpetual Contract Trading**: Real order execution on Hyperliquid DEX
  - Market and limit orders with 1-50x leverage support
  - Long and short positions with automatic liquidation price calculation
  - Cross-margin mode with real-time margin usage monitoring
- **Environment Isolation**: Strict separation of Testnet and Mainnet
  - Separate wallet configurations per environment
  - Environment-aware caching with `(account_id, environment)` composite keys
  - API call isolation preventing cross-environment data contamination
- **Risk Management**: Built-in safety mechanisms
  - Maximum leverage limits (configurable per account, 1-50x)
  - Margin usage alerts (auto-pause trading at 80% usage)
  - Liquidation price display and warnings
- **AI-Driven Trading**: LLM-powered perpetual contract trading
  - Leverage-aware AI prompts with risk management education
  - Automatic leverage selection based on market confidence
  - Full integration with existing AI decision engine

## Screenshots

### Dashboard Overview
![Dashboard Overview](screenshots/dashboard-overview.png)

### AI Prompt Generator
![AI Prompt Generator](screenshots/ai-prompt-generator.png)

### Technical Analysis
![Technical Analysis](screenshots/ai-technical-analysis.png)

### Trader Configuration
![Trader Configuration](screenshots/trader-configuration.png)

## Quick Start

### Prerequisites

- **Docker Desktop** ([Download](https://www.docker.com/products/docker-desktop))
  - Windows: Docker Desktop for Windows
  - macOS: Docker Desktop for Mac
  - Linux: Docker Engine ([Install Guide](https://docs.docker.com/engine/install/))

### Installation

```bash
# Clone the repository
git clone https://github.com/HammerGPT/Hyper-Alpha-Arena.git
cd Hyper-Alpha-Arena

# Start the application (choose one command based on your Docker version)
docker compose up -d --build        # For newer Docker Desktop (recommended)
# OR
docker-compose up -d --build       # For older Docker versions or standalone docker-compose
```

The application will be available at **http://localhost:8802**

### Managing the Application

```bash
# View logs
docker compose logs -f        # (or docker-compose logs -f)

# Stop the application
docker compose down          # (or docker-compose down)

# Restart the application
docker compose restart       # (or docker-compose restart)

# Update to latest version
git pull origin main
docker compose up -d --build # (or docker-compose up -d --build)
```

**Important Notes:**
- All data (databases, configurations, trading history) is persisted in Docker volumes
- Data will be preserved when you stop/restart containers
- Only `docker-compose down -v` will delete data (don't use `-v` flag unless you want to reset everything)

## First-Time Setup

### Understanding Hyperliquid Authentication

Hyperliquid is a decentralized exchange (DEX) where all trading operations are executed as on-chain transactions. Unlike centralized exchanges that use API keys, DEX platforms require **private keys** to cryptographically sign each transaction on the blockchain. This is not a limitation but a fundamental requirement of decentralized architecture - your trades are executed directly on-chain without intermediaries.

**Official Documentation:**
- Hyperliquid API Signing: https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/signing
- Python SDK: https://github.com/hyperliquid-dex/hyperliquid-python-sdk

**Our Security Measures:**
- Private keys are encrypted using AES-256 before storage
- All encryption/decryption happens locally on your server
- Keys are never transmitted in plain text
- We recommend using a dedicated trading wallet separate from your main holdings

### Setup Steps

**1. Create Your First AI Trader**

Open http://localhost:8802 and navigate to **AI Traders** section:
- Name: e.g., "GPT-5 Trader"
- Model: Select from dropdown (gpt-5-mini, claude-sonnet-4.5, deepseek-chat, etc.)
- API Key: Your LLM provider API key (OpenAI/Anthropic/Deepseek)
- Base URL: Leave default or use custom endpoint

**2. Configure Hyperliquid Wallet**

In the **Hyperliquid Wallets** section, you'll see two wallet panels:
- **Testnet Wallet**: For risk-free testing with free test funds
- **Mainnet Wallet**: For real trading with actual capital

For each wallet:
- Enter your Hyperliquid private key (get it from https://app.hyperliquid-testnet.xyz/ or https://app.hyperliquid.xyz/)
- Set maximum leverage (1-50x)
- Set default leverage (1-3x recommended)
- Click **Save Wallet**

**3. Set Global Trading Environment**

Navigate to **Settings** or **Hyperliquid** page:
- **TESTNET**: All AI Traders use testnet wallets (recommended for initial testing)
- **MAINNET**: All AI Traders use mainnet wallets (real money)

**4. Enable Auto Trading**

In your AI Trader configuration:
- Toggle **Auto Trading** to ON
- Set Trigger Mode: Real-time (recommended)
- Set Trigger Interval: 60-150 seconds
- Choose Prompt Template: "Hyperliquid Pro" includes leverage education
- Monitor initial trades in **System Logs**

### Safety Recommendations

These are suggestions based on best practices. Many users have different risk preferences:
- Consider testing on testnet first to understand system behavior
- Starting with lower leverage (1x-3x) can help you learn the system
- Monitoring margin usage helps avoid unexpected liquidations
- Using dedicated trading wallets (separate from main holdings) is a common security practice
- Some users prefer gradual scaling rather than maximum leverage from the start

## Supported Models

Hyper Alpha Arena supports any OpenAI API compatible language model. **For best results, we recommend using Deepseek** for its cost-effectiveness and strong performance in trading scenarios.

Supported models include:
- **Deepseek** (Recommended): Excellent cost-performance ratio for trading decisions
- **OpenAI**: GPT-5 series, o1 series, GPT-4o, GPT-4
- **Anthropic**: Claude (via compatible endpoints)
- **Custom APIs**: Any OpenAI-compatible endpoint

The platform automatically handles model-specific configurations and parameter differences.

## Troubleshooting

### Common Issues

**Problem**: Port 8802 already in use
**Solution**:
```bash
docker-compose down
docker-compose up -d --build
```

**Problem**: Cannot connect to Docker daemon
**Solution**: Make sure Docker Desktop is running

**Problem**: Database connection errors
**Solution**: Wait for PostgreSQL container to be healthy (check with `docker-compose ps`)

**Problem**: Want to reset all data
**Solution**:
```bash
docker-compose down -v  # This will delete all data!
docker-compose up -d --build
```

## Contributing

We welcome contributions from the community! Here are ways you can help:

- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation
- Test on different platforms

Please star and fork this repository to stay updated with development progress.

## Resources

### Hyperliquid
- Official Docs: https://hyperliquid.gitbook.io/
- Python SDK: https://github.com/hyperliquid-dex/hyperliquid-python-sdk
- Testnet: https://api.hyperliquid-testnet.xyz

### Original Project
- Open Alpha Arena: https://github.com/etrobot/open-alpha-arena

## Community & Support

**🌐 Official Website**: [https://www.akooi.com/](https://www.akooi.com/)

**🐦 Contact me on Twitter/X**: [@GptHammer3309](https://x.com/GptHammer3309)
- Latest updates on Hyper Alpha Arena development
- AI trading insights and strategy discussions
- Technical support and Q&A


Join our ([Telegram group](https://t.me/+RqxjT7Gttm9hOGEx)) for real-time discussions and faster triage .
- Report bugs (please include logs, screenshots, and steps if possible)
- Share strategy insights or product feedback
- Ping me about PRs/Issues so I can respond quickly

Friendly reminder: Telegram is for rapid communication, but final tracking and fixes still go through GitHub Issues/Pull Requests. Never post API keys or other sensitive data in the chat.

欢迎加入（[Telegram 群](https://t.me/+RqxjT7Gttm9hOGEx)）：
- 反馈 Bug（尽量附日志、截图、复现步骤）
- 讨论策略或产品体验
- PR / Issue 想要我关注可在群里提醒

注意：Telegram 主要用于快速沟通，正式记录请继续使用 GitHub Issues / Pull Requests；谨记不要分享密钥等敏感信息。

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **etrobot** - Original open-alpha-arena project
- **nof1.ai** - Inspiration from Alpha Arena
- **Hyperliquid** - Decentralized perpetual exchange platform
- **OpenAI, Anthropic, Deepseek** - LLM providers

---

Star this repository to follow development progress.
