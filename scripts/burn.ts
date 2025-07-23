import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { fromHex } from '@mysten/bcs'
import { normalizeSuiAddress } from '@mysten/sui/utils'

export const burn = async (suiClient: SuiClient, tx: Transaction) => {
    const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')
    const receipt = process.env.RECEIPT_ADDRESS || ''
  
    tx.moveCall({
      target: `0x2::coin::burn`,
      typeArguments: [config.sbtc_coin_type()],
      arguments: [
        tx.object(config.sbtc_treasury()),
        tx.object(process.env.TOKEN_OBJECT_ID),
      ],
    })
  
    const result = await suiClient.signAndExecuteTransaction({
      transaction: tx,
      signer: keypair,
    })
  
    console.log('burn result:', result)
} 