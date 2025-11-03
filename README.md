# Bridge Move - Sui Cross-Chain Bridge

A cross-chain bridge smart contract project built on Sui blockchain, enabling secure token transfers across multiple chains.

## 📋 Overview

This project implements a decentralized cross-chain bridge solution that enables secure token transfers between Sui and other blockchain networks. The smart contracts are written in Move, with TypeScript scripts providing comprehensive interaction and management capabilities.

## ✨ Core Features

### Token Bridging
- **Send Tokens**: Transfer tokens from Sui to other chains
- **Receive Tokens**: Receive and mint tokens from other chains
- **Transfer Records**: Complete tracking of cross-chain transfer statuses (pending, approved, claimed)

### Committee Management
- Multi-signature committee verification mechanism
- Committee member registration and management
- Committee blocklist functionality
- Configurable participation threshold

### Route and Token Management
- Support for multiple chains and token types
- Configurable cross-chain routes
- Dynamic addition of new tokens and routes
- Token metadata management

### Fee and Limit Management
- Configurable cross-chain transaction fees
- Transfer limit management
- Minimum transfer amount settings
- Dynamic fee adjustment

### System Administration
- Emergency pause/resume functionality
- Admin permission management
- Version upgrade support
- Treasury management

## 🏗️ Project Structure

```
bridge-move/
├── sources/                    # Move smart contract source code
│   ├── bridge.move            # Main bridge contract
│   ├── committee.move         # Committee management module
│   ├── message.move           # Message handling module
│   ├── message_types.move     # Message type definitions
│   ├── chain_ids.move         # Chain ID management
│   ├── limiter.move           # Transfer limiter
│   ├── treasury.move          # Treasury management
│   └── crypto.move            # Cryptographic verification module
├── scripts/                    # TypeScript interaction scripts
│   ├── send_token.ts          # Send token script
│   ├── approve_token_transfer_and_claim.ts  # Approve and claim tokens
│   ├── create_committee.ts    # Create committee
│   ├── register_token.ts      # Register token
│   ├── execute_*.ts           # Various execution scripts
│   └── config.ts              # Configuration file
├── tests/                      # Test files
│   ├── bridge_tests.move      # Bridge tests
│   └── bridge_env.move        # Test environment
├── build/                      # Compilation output
├── Move.toml                   # Move project configuration
└── package.json                # Node.js dependencies
```

## 🚀 Quick Start

### Prerequisites

- [Sui CLI](https://docs.sui.io/build/install)
- [Node.js](https://nodejs.org/) (v16+)
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)

### Installation

```bash
# Install Node.js dependencies
npm install

# Ensure Sui CLI is installed and configured
sui --version
```

### Build

```bash
# Build using Makefile
sui move build --skip-fetch-latest-git-deps

```

### Testing

```bash
# Run Move tests
sui move test --skip-fetch-latest-git-deps
```

### Deployment

```bash
# Deploy contract (requires Sui client configuration)
bash scripts/deploy.sh
```

## 📝 Configuration

Before using the scripts, you need to configure environment variables. Create a `.env` file and set the following variables:

```bash
# Contract address configuration
PACKAGE=<deployed package ID>
BRIGE_OBJECT_ID=<bridge object ID>
ADMIN_CAP_ID=<admin capability ID>
UPGRADE_CAP_ID=<upgrade capability ID>

# Account configuration
ADMIN_PRIVATE_KEY=<admin private key>
SUBMITTER=<submitter address, can call approve_token_transfer method>

# Committee configuration
COMMITTEE1=<committee member 1 address>
COMMITTEE2=<committee member 2 address>
# or more

# Token configuration (example)
SBTC_COIN_TYPE=<token type>
SBTC_METADATA=<token metadata ID>
SBTC_TREASURY=<token treasury ID>
```

## 🔧 Scripts Overview

### Token Operations

- **`send_token.ts`**: Send tokens to other chains
- **`approve_token_transfer_and_claim.ts`**: Approve token transfer and claim
- **`register_token.ts`**: Register new cross-chain token

### Committee Management

- **`create_committee.ts`**: Create bridge committee
- **`committee_registration.ts`**: Register committee members
- **`execute_update_blocklist.ts`**: Update committee blocklist

### System Configuration

- **`execute_update_bridge_limit.ts`**: Update cross-chain transfer limits
- **`execute_update_fee_percentage.ts`**: Update fee percentage
- **`execute_update_bridge_min_amount.ts`**: Update minimum transfer amount
- **`execute_add_tokens_on_sui.ts`**: Add new token support
- **`execute_add_routes_on_sui.ts`**: Add new routes
- **`execute_update_token_price.ts`**: Update token price
- **`update_submitter.ts`**: Update submitter
- **`withdraw_treasury.ts`**: Withdraw from treasury

### Version Management

- **`migrate_admin_cap_version.ts`**: Migrate admin capability version
- **`migrate_bridge_version.ts`**: Migrate bridge contract version
- **`upgrade.sh`**: Upgrade script

## 🔐 Security Features

1. **Multi-signature Verification**: All cross-chain messages require committee multi-signature verification
2. **Replay Protection**: Sequence numbers prevent message replay attacks
3. **Limit Controls**: Configurable transfer limits per route
4. **Emergency Pause**: Admins can pause the bridge in emergency situations
5. **Version Management**: Support for contract version upgrades and migrations

## 📊 Message Types

The system supports the following message types:

- `TOKEN_TRANSFER (0)`: Token transfer
- `COMMITTEE_BLOCKLIST (1)`: Committee blocklist update
- `EMERGENCY_OP (2)`: Emergency operation (pause/resume)
- `UPDATE_BRIDGE_LIMIT (3)`: Update transfer limit
- `UPDATE_ASSET_PRICE (4)`: Update asset price
- `ADD_TOKENS_ON_SUI (6)`: Add tokens
- `ADD_ROUTES_ON_SUI (7)`: Add routes
- `UPDATE_BRIDGE_MIN_AMOUNT (8)`: Update minimum amount
- `UPDATE_BRIDGE_FEE_PERCENTAGE (9)`: Update fee percentage

## 🧪 Testing

The project includes a comprehensive test suite located in the `tests/` directory:

```bash
# Run all tests
sui move test

# Run specific test file
sui move test bridge_tests
```

## 🔗 Related Resources

- [Sui Official Documentation](https://docs.sui.io/)
- [Move Language Documentation](https://move-language.github.io/move/)
- [Sui TypeScript SDK](https://github.com/MystenLabs/sui/tree/main/sdk/typescript)

## ⚠️ Important Notes

1. **Testnet Usage**: The project is currently configured to use Sui testnet framework
2. **Private Key Security**: Never hardcode private keys in code, use environment variables
3. **Version Compatibility**: Ensure Sui CLI version is compatible with the framework version used by the project
4. **Production Deployment**: Please conduct thorough audits and testing before deploying to production

## 📞 Contact

For questions or suggestions, please contact via GitHub Issues.
