# Oracle Bridge 🌉

A decentralized oracle network for Stacks blockchain featuring reputation-based consensus, multi-source validation, and automated dispute resolution.

## 🎯 Overview

Oracle Bridge provides reliable off-chain data to smart contracts through a network of incentivized data providers. The protocol ensures data accuracy through economic stakes, reputation scoring, and consensus mechanisms, making it ideal for DeFi protocols, prediction markets, and any application requiring external data.

## ⚡ Key Features

### 1. **Reputation System**
- Dynamic scoring (0-10,000 scale)
- Performance-based adjustments
- Reputation decay mechanism
- Bonus rewards for high reputation

### 2. **Multi-Source Validation**
- Up to 20 providers per feed
- Median aggregation algorithm
- Confidence scoring
- Deviation thresholds (5% max)

### 3. **Economic Security**
- Minimum 10 STX stake requirement
- 20% slashing for malicious behavior
- Reputation-weighted rewards
- Protocol fee distribution

### 4. **Data Feed Types**
- **Price Feeds**: Cryptocurrency, stocks, commodities
- **Weather Data**: Temperature, precipitation, conditions
- **Sports Results**: Scores, statistics, outcomes
- **Custom Feeds**: Any verifiable external data

### 5. **Dispute Resolution**
- 12-hour dispute window
- Evidence submission system
- Slash malicious providers
- Admin resolution (upgradeable to DAO)

## 📋 Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) >= 1.0.0
- [Stacks CLI](https://docs.stacks.co/docs/cli)
- Node.js >= 14.0.0
- Minimum 10 STX for provider registration

## 🚀 Installation

1. **Clone Repository**
```bash
git clone https://github.com/yourusername/oracle-bridge.git
cd oracle-bridge
```

2. **Install Dependencies**
```bash
npm install
clarinet install
```

3. **Verify Contract**
```bash
clarinet check
clarinet test
```

## 💻 Quick Start

### Deploy Contract
```bash
# Local deployment
clarinet console
> (deploy-contract 'oracle-bridge)

# Testnet deployment
clarinet deploy --testnet

# Mainnet deployment
clarinet deploy --mainnet
```

### Provider Registration

#### 1. Register as Oracle Provider
```clarity
;; Stake 10 STX minimum to become a provider
(contract-call? .oracle-bridge register-provider u10000000)
```

#### 2. Create Data Feed
```clarity
;; Create a BTC/USD price feed
(contract-call? .oracle-bridge create-feed 
    "BTC-USD"                    ;; feed-id
    "Bitcoin USD Price Feed"     ;; description
    "price"                      ;; data-type
    u6                          ;; update every 6 blocks (~1 hour)
    "median"                    ;; aggregation method
)
```

#### 3. Submit Data
```clarity
;; Submit price data (in cents, so $50,000 = 5000000)
(contract-call? .oracle-bridge submit-data 
    "BTC-USD"      ;; feed-id
    u5000000       ;; value ($50,000)
    u100           ;; timestamp (block height)
)
```

#### 4. Claim Rewards
```clarity
;; Claim rewards for accurate submissions
(contract-call? .oracle-bridge claim-rewards 
    "BTC-USD"      ;; feed-id
    u100           ;; timestamp
)
```

## 📚 API Reference

### Core Functions

| Function | Description | Parameters | Access |
|----------|-------------|------------|--------|
| `register-provider` | Register as data provider | `stake-amount: uint` | Public |
| `create-feed` | Create new data feed | `feed-id, description, type, frequency, method` | Public |
| `authorize-provider` | Authorize provider for feed | `feed-id, provider` | Feed creator |
| `submit-data` | Submit data to feed | `feed-id, value, timestamp` | Authorized providers |
| `aggregate-data` | Aggregate provider submissions | `feed-id, timestamp, providers` | Public |
| `claim-rewards` | Claim submission rewards | `feed-id, timestamp` | Providers |
| `dispute-data` | Dispute submitted data | `feed-id, timestamp, evidence` | Public |
| `withdraw-stake` | Withdraw staked tokens | - | Providers |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-feed-info` | Get feed configuration | Feed details |
| `get-latest-data` | Get most recent data | Value & confidence |
| `get-provider-info` | Get provider statistics | Provider data |
| `get-submission` | Get specific submission | Submission details |
| `calculate-provider-accuracy` | Calculate accuracy rate | Percentage (basis points) |
| `is-feed-provider` | Check provider authorization | Boolean |

### Admin Functions

| Function | Description | Access |
|----------|-------------|--------|
| `emergency-stop` | Pause all operations | Owner only |
| `emergency-resume` | Resume operations | Owner only |
| `withdraw-protocol-revenue` | Withdraw fees | Owner only |
| `resolve-dispute` | Resolve dispute | Owner only |
| `update-feed-status` | Enable/disable feed | Feed creator |

## 🏗️ Architecture

### Data Flow
```
1. Providers stake STX and register
2. Feed creators define data requirements
3. Authorized providers submit data
4. System aggregates using median
5. Consumers read aggregated data
6. Disputes trigger investigation
7. Rewards/penalties distributed
```

### Consensus Mechanism
- **Threshold**: 60% provider agreement required
- **Deviation**: Maximum 5% from median allowed
- **Confidence**: Based on provider participation
- **Validation**: Automatic outlier detection

### Reputation Calculation
```
Base Score: 5,000 (neutral start)
Accurate submission: +100 points
Inaccurate submission: -200 points
Slash event: -1,000 points
Maximum score: 10,000
Minimum score: 0
```

## 💰 Economics

### Provider Incentives
| Action | Reward/Penalty |
|--------|---------------|
| Accurate submission | 0.1 STX + reputation bonus |
| Inaccurate submission | -200 reputation |
| Malicious behavior | 20% stake slash |
| High reputation (>8000) | 2x reward multiplier |

### Fee Structure
- **Minimum Stake**: 10 STX
- **Submission Reward**: 0.1 STX base
- **Slashing Rate**: 20% of stake
- **Dispute Period**: 72 blocks (~12 hours)
- **Minimum Lock**: 1,440 blocks (~10 days)

### Reputation Tiers
| Tier | Score Range | Benefits |
|------|------------|----------|
| Trusted | 8,000-10,000 | 2x rewards, priority access |
| Reliable | 6,000-7,999 | 1.5x rewards |
| Standard | 4,000-5,999 | 1x rewards |
| Probation | 2,000-3,999 | 0.5x rewards |
| Restricted | 0-1,999 | Cannot submit data |

## 🔒 Security

### Protection Mechanisms
1. **Economic Stakes**: Providers must stake STX
2. **Reputation Risk**: Poor performance reduces earnings
3. **Slashing**: Malicious actors lose stake
4. **Time Locks**: Minimum staking period enforced
5. **Emergency Pause**: Admin can halt operations

### Best Practices
- Verify multiple providers before trusting data
- Check confidence scores before using values
- Monitor dispute resolutions
- Diversify provider selection
- Implement fallback mechanisms

## 🧪 Testing

### Run Tests
```bash
# Run all tests
clarinet test

# Run specific test suite
clarinet test --filter oracle-tests

# Generate coverage report
clarinet test --coverage
```

### Test Scenarios
- ✅ Provider registration and staking
- ✅ Feed creation and configuration
- ✅ Data submission and aggregation
- ✅ Reputation updates
- ✅ Reward distribution
- ✅ Dispute handling
- ✅ Slashing mechanisms
- ✅ Emergency procedures

## 📊 Contract Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `min-stake-amount` | 10 STX | Minimum provider stake |
| `max-providers-per-feed` | 20 | Maximum providers per feed |
| `dispute-period` | 72 blocks | Dispute window |
| `slash-percentage` | 20% | Stake slashing rate |
| `reward-per-submission` | 0.1 STX | Base submission reward |
| `consensus-threshold` | 60% | Required agreement |
| `max-deviation` | 5% | Maximum deviation from median |
| `reputation-decay` | 10 points/period | Reputation decay rate |

## 🛠️ Development

### Project Structure
```
oracle-bridge/
├── contracts/
│   └── oracle-bridge.clar     # Main contract
├── tests/
│   ├── unit/
│   │   ├── provider_test.ts   # Provider tests
│   │   ├── feed_test.ts       # Feed tests
│   │   └── dispute_test.ts    # Dispute tests
│   └── integration/
│       └── e2e_test.ts         # End-to-end tests
├── scripts/
│   ├── deploy.ts              # Deployment script
│   ├── setup-feeds.ts         # Feed initialization
│   └── monitor.ts             # Monitoring script
├── docs/
│   ├── architecture.md        # Technical design
│   └── integration.md         # Integration guide
├── Clarinet.toml              # Project config
└── README.md                  # Documentation
```

### Local Development
```bash
# Start console
clarinet console

# Deploy contract
(deploy-contract .oracle-bridge)

# Register as provider
(contract-call? .oracle-bridge register-provider u10000000)

# Create test feed
(contract-call? .oracle-bridge create-feed "TEST" "Test Feed" "price" u6 "median")
```

## 🔗 Integration Guide

### For DeFi Protocols
```clarity
;; Read price data in your contract
(define-read-only (get-btc-price)
    (match (contract-call? .oracle-bridge get-latest-data "BTC-USD")
        data (ok (get value data))
        err (err u404)))
```

### For Data Providers
```javascript
// Automated submission script
async function submitPrice() {
    const price = await fetchPrice('BTC-USD');
    const tx = await contract.submitData(
        'BTC-USD',
        Math.floor(price * 100), // Convert to cents
        blockHeight
    );
    return tx;
}
```

## 🗺️ Roadmap

### Phase 1 - Foundation ✅
- [x] Core oracle functionality
- [x] Reputation system
- [x] Basic dispute resolution
- [x] Provider management

### Phase 2 - Enhancement (Q1 2025)
- [ ] Governance token
- [ ] Decentralized dispute resolution
- [ ] Cross-chain data bridges
- [ ] Advanced aggregation methods

### Phase 3 - Scaling (Q2 2025)
- [ ] Layer 2 integration
- [ ] Batch submissions
- [ ] Gas optimizations
- [ ] Provider pools

### Phase 4 - Ecosystem (Q3 2025)
- [ ] SDK development
- [ ] Dashboard and analytics
- [ ] Automated provider tools
- [ ] Insurance mechanisms

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### How to Contribute
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add feature'`)
4. Push branch (`git push origin feature/amazing`)
5. Open Pull Request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

**IMPORTANT NOTICE**: This oracle system handles critical data for smart contracts. Users should:

- Thoroughly audit the code before production use
- Implement proper error handling in consuming contracts
- Use multiple providers for critical data
- Monitor feed health and dispute rates
- Understand the economic risks of providing data
- Never rely on a single data source

The protocol is provided "as is" without warranties. Users assume all risks.

## 🆘 Support

### Resources
- **Documentation**: [docs.oraclebridge.io](https://docs.oraclebridge.io)
- **GitHub Issues**: [Report bugs](https://github.com/oracle-bridge/issues)
- **Discord**: [Join community](https://discord.gg/oracle-bridge)
- **Twitter**: [@OracleBridge](https://twitter.com/oraclebridge)
- **Email**: support@oraclebridge.io

### FAQs

**Q: How quickly can I withdraw my stake?**
A: After 10 days (1,440 blocks) from registration.

**Q: What happens if I submit incorrect data?**
A: Your reputation decreases and you may be slashed if malicious.

**Q: How are disputes resolved?**
A: Currently by admin, will transition to DAO governance.

**Q: Can I run multiple provider nodes?**
A: Yes, but each requires a separate stake.

**Q: What data types are supported?**
A: Any numerical data that can be independently verified.

---

**Built with ❤️ for the Stacks Ecosystem**

*Oracle Bridge - Connecting Blockchains to Reality*
