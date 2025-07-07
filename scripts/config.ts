import { getAddress } from 'ethers'

export const COMMITTEE_MESSAGE_PREFIX = 'SUI_BRIDGE_MESSAGE'

export const MessageVersion = 1

export const config = {
  id: 16,
  package: () => process.env.PACKAGE || '',
  admin_cap: () => process.env.ADMIN_CAP_ID || '',
  bridge: () => process.env.BRIGE_OBJECT_ID || '',
  admin: () => process.env.ADMIN_PRIVATE_KEY || '',
  submitter: () => process.env.SUBMITTER || '',
  sbtc_coin_type: () => process.env.SBTC_COIN_TYPE || '',
  sbtc_metadata: () => process.env.SBTC_METADATA || '',
  sbtc_treasury: () => process.env.SBTC_TREASURY || '',
  committees: [
    {
      privateKey: () => process.env.ADMIN_PRIVATE_KEY || '',
      staked: 10001,
      isblacklisted: false,
    }
  ],
  supported_chains: {
    250: [
      {
        token_id: 88,
        fee_percentage: 1000,
        bridge_amount: 0,
        supported: true,
        limit: 10 ** 8 * 1000,
      },
    ],
  },
}

export enum MessageType {
  TOKEN_TRANSFER = 0,
  COMMITTEE_BLOCKLIST = 1,
  EMERGENCY_OP = 2,
  UPDATE_BRIDGE_LIMIT = 3,
  UPDATE_ASSET_PRICE = 4,
  ADD_TOKENS_ON_SUI = 6,
  ADD_ROUTES_ON_SUI = 7,
}
