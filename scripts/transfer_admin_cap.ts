import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { fromHex } from '@mysten/bcs'
import { normalizeSuiAddress } from '@mysten/sui/utils'

export const transferAdminCap = async (suiClient: SuiClient, tx: Transaction) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')
  const rawNewAdmin = process.env.NEW_ADMIN_ADDRESS || ''
  
  // 规范化地址格式
  const newAdmin = normalizeSuiAddress(rawNewAdmin)
  console.log('newAdmin', newAdmin)

  if (!newAdmin) {
    throw new Error('Invalid NEW_ADMIN_ADDRESS')
  }

  tx.transferObjects([
    tx.object(config.admin_cap()),
  ], newAdmin)

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })

  console.log('transferAdminCap result:', result)
} 