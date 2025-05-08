# SSI-BotMarginPool Project

A Solidity smart contract project for managing liquidity pools with zkEVM verification.

## Project Structure

- `src/LPManager.sol`: Main contract for managing liquidity pools
- `src/Deposit.sol`: Contract for handling deposits
- `src/Withdraw.sol`: Contract for handling withdrawals
- `scripts/deploy.js`: Deployment script
- `test/LPManager.test.js`: Test suite for the LPManager contract

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file with your private key:
```
PRIVATE_KEY=your_private_key_here
```

3. Compile contracts:
```bash
npx hardhat compile
```

4. Run tests:
```bash
npx hardhat test
```

5. Deploy to Polygon zkEVM testnet:
```bash
npx hardhat run scripts/deploy.js --network polygonZkTestnet
```

## Features

- Liquidity pool management
- POL deposit handling
- zkEVM verification
- Secure withdrawal mechanism

## License

MIT
