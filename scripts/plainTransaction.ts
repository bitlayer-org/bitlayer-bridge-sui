import { getFullnodeUrl, SuiClient } from '@mysten/sui/client'
import { configDotenv } from 'dotenv'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { toHex, fromHex } from '@mysten/bcs'

configDotenv()

async function main() {
  const suiClient = new SuiClient({ url: getFullnodeUrl('mainnet') })
  const tx = new Transaction()
  const receipt = process.env.RECEIPT_ADDRESS || ''

  // tx.moveCall({
  //   target: `${config.package()}::bridge::withdraw_treasury`,
  //   typeArguments: [config.sbtc_coin_type()],
  //   arguments: [
  //     tx.object(config.bridge()),
  //     tx.object(config.admin_cap()),
  //     tx.pure.address(receipt),
  //   ],
  // })
  tx.moveCall({
    target: `${config.package()}::bridge::register_foreign_token`,
    typeArguments: [config.sbtc_coin_type()],
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.sbtc_treasury()),
      tx.object(config.sbtc_metadata()),
    ],
  })

  tx.setSender("0xc23370b55d3deca6a8c97437ab47e3cd6369756a623b5ae023c4be70ccb1f139")

  let txBytes = await tx.build({
    client: suiClient
  })
  console.log(toHex(txBytes))
}
main().catch((error) => {
  console.error(error)
})
