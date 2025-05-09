## 📄 DeliverChain - README

### 🚀 Overview

**DeliverChain** is a Clarity smart contract built for the Stacks blockchain, designed to create a decentralized package delivery system. It enables users to:

* Register delivery packages
* Assign delivery agents
* Track package statuses
* Log customer delivery history
* Incentivize agents based on performance
* Process delivery fees based on size, urgency, and insurance coverage

The contract includes token balances for users and agents to manage delivery-related payments, with various validation rules to ensure delivery integrity and transparency.

---

### ⚙️ Features

* 📦 **Package Creation**: Customers can register packages with size, urgency, insurance, and delivery time.
* 👷 **Agent Assignment**: Delivery agents accept jobs and stake tokens equivalent to package size.
* ✅ **Delivery Confirmation**: Upon successful delivery, the agent is rewarded with fees based on urgency and coverage.
* 🛡 **Insurance & Fees**: Delivery fees are calculated dynamically from package size, urgency level, and optional insurance.
* 📊 **Performance Tracking**: Agents earn performance points upon successful delivery.
* 📚 **Customer History**: Each customer can view a log of their last 10 package IDs.
* 🧾 **Token Management**: Users can add tokens to their balance and view balances on-chain.
* ❌ **Termination**: Packages can be canceled if not yet assigned.

---

### 📜 Smart Contract Functions

#### ✅ Public Functions

* `create-package(...)`: Register a new package for delivery.
* `accept-delivery(package-id)`: Agent accepts responsibility for delivering a package.
* `confirm-receipt(package-id)`: Customer confirms package delivery and triggers payment.
* `terminate-package(package-id)`: Owner can cancel package before it’s picked up.
* `add-tokens(amount)`: Add tokens to caller’s balance.

#### 🔍 Read-Only Functions

* `get-package-details(package-id)`: View details of a specific package.
* `check-balance(user)`: View token balance of a user.
* `get-agent-score(agent)`: Check agent’s performance score.
* `view-customer-packages(customer)`: View last 10 package IDs created by a customer.
* `calculate-urgency-bonus(urgency-level)`: Get bonus multiplier for a given urgency level.

---

### 🛠 Data Maps & Structures

* `package-registry`: Stores metadata of each package.
* `token-balances`: Ledger of user balances.
* `agent-performance`: Scores for successful deliveries by agents.
* `customer-package-log`: Last 10 package IDs per customer.

---

### 🔐 Error Codes

| Code   | Error Description          |
| ------ | -------------------------- |
| `u100` | Permission denied          |
| `u101` | Package already in transit |
| `u102` | Balance too low            |
| `u103` | Package unavailable        |
| `u104` | Delivery still in progress |
| `u105` | Invalid package size       |
| `u106` | Invalid coverage rate      |
| `u107` | Invalid delivery time      |
| `u108` | Invalid package ID         |
| `u109` | Invalid urgency level      |
| `u110` | Package already terminated |

---

### 🧪 Example Flow

1. Customer funds their balance using `add-tokens`.
2. Customer calls `create-package` to post a delivery job.
3. Agent calls `accept-delivery` to take on the delivery.
4. After delivery time, the customer calls `confirm-receipt` to release payment.
5. Agent receives token reward and performance points.
