# 🌾 Crop Rotation Scheduler Smart Contract

> Revolutionizing sustainable agriculture through blockchain technology

## 🎯 Overview

The Crop Rotation Scheduler is a smart contract that incentivizes sustainable farming practices by rewarding farmers for following proper crop rotation cycles. Built on the Stacks blockchain, it transforms agricultural plots into NFTs and tracks farming compliance through oracle verification.

## 🚀 Key Features

- **🏞️ Plot Registration**: Register farm plots as NFTs with location and size data
- **🔄 Rotation Management**: Enforce scientifically-backed crop rotation schedules
- **🏆 Reward System**: Earn tokenized rewards for sustainable farming practices
- **👁️ Oracle Verification**: Third-party verification of farming compliance
- **📊 Analytics**: Track farmer statistics and compliance scores
- **⏸️ Contract Controls**: Admin controls for pausing and oracle management

## 🌱 Supported Crop Types

| ID | Crop Type | Category | Season Length |
|----|-----------|----------|---------------|
| 1  | Legumes   | Nitrogen-fixing | 144 blocks |
| 2  | Cereals   | Grains | 288 blocks |
| 3  | Tubers    | Root vegetables | 216 blocks |
| 4  | Vegetables| Leafy greens | 144 blocks |

## 🔄 Rotation Rules

✅ **Optimal Rotations** (Higher Rewards):
- Legumes → Cereals (20% bonus)
- Vegetables → Legumes (25% bonus)
- Cereals → Tubers (10% bonus)
- Tubers → Vegetables (15% bonus)

⚠️ **Alternative Rotations** (Standard Rewards):
- Legumes → Tubers (5% bonus)
- Cereals → Vegetables (5% bonus)

## 📋 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Crop-Rotation-Scheduler-Contract

# Check contract syntax
clarinet check

# Install dependencies for testing
npm install

# Run tests
npm test
```

## 🔧 Contract Usage

### Initialize the Contract

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract initialize-contract)
```

### Register a Farm Plot

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract register-plot 
  u10    ;; size in acres
  "North Field Farm A"  ;; location
  u1     ;; initial crop (legumes)
)
```

### Rotate Crops

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract rotate-crop 
  u1     ;; plot-id
  u2     ;; new crop type (cereals)
)
```

### Claim Rewards

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract claim-rewards u1)
```

## 👥 Oracle System

### Add Oracle (Admin Only)

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract add-oracle 'SP1ORACLE...)
```

### Verify Compliance (Oracle Only)

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract verify-compliance 
  u1      ;; plot-id
  u12345  ;; block height when crop was planted
)
```

## 📊 Read-Only Functions

### Get Plot Information

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract get-plot-info u1)
```

### Check Farmer Statistics

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract get-farmer-stats 'SP1FARMER...)
```

### View Contract Statistics

```clarity
(contract-call? .Crop-Rotation-Scheduler-Contract get-contract-stats)
```

## 💰 Reward System

**Base Reward Formula:**
```
Reward = BASE_REWARD × Plot_Size + Streak_Bonus
Streak_Bonus = (Base × Compliance_Streak) ÷ 10
```

**Example:**
- 10-acre plot with 5 successful rotations
- Base: 1000 × 10 = 10,000 tokens
- Streak bonus: 10,000 × 5 ÷ 10 = 5,000 tokens
- **Total: 15,000 tokens**

## 🔒 Security Features

- ✅ Owner-only administrative functions
- ✅ Oracle authorization system
- ✅ Plot ownership verification
- ✅ Rotation timing enforcement
- ✅ Emergency pause functionality
- ✅ Input validation and error handling

## ⚙️ Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `ROTATION-CYCLE-BLOCKS` | 1008 | Blocks before rewards can be claimed |
| `MIN-COMPLIANCE-PERIOD` | 144 | Minimum blocks between rotations |
| `BASE-REWARD` | 1000 | Base reward amount per unit size |

## 🧪 Testing

Run the test suite:

```bash
npm test
```

The tests cover:
- Contract initialization
- Plot registration and management
- Crop rotation validation
- Oracle verification system
- Reward calculation and distribution
- Error handling scenarios

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🌍 Impact

**Environmental Benefits:**
- 🌱 Improved soil health through proper rotation
- 🧪 Reduced chemical fertilizer dependency
- 📈 Long-term yield improvements
- 🌿 Enhanced biodiversity in agricultural systems

**Economic Benefits:**
- 💰 Tokenized rewards for sustainable practices
- 📊 Transparent compliance tracking
- 🤝 Trust through blockchain verification
- 📈 Potential for carbon credit integration

---

**Made with 💚 for sustainable agriculture**
