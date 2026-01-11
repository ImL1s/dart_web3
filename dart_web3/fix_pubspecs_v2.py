import os
import re

# Roots to process
roots = [
    r'D:\OtherProject\mine\dart_web3\dart_web3\packages',
    r'D:\OtherProject\mine\dart_web3\dart_web3\web3_universal'
]

# Mapping of package name to version
# Ensure these versions are correct and match what is on pub.dev or what is intended
replacements = {
    'web3_universal_core': '^0.1.1',
    'web3_universal_crypto': '^0.2.0',
    'web3_universal_abi': '^0.1.1',
    'web3_universal_chains': '^0.1.0+1',
    'web3_universal_signer': '^0.1.1',
    'web3_universal_provider': '^0.1.0+1',
    'web3_universal_client': '^0.1.1+1',
    'web3_universal_contract': '^0.1.0+1',
    'web3_universal_ens': '^0.1.1+1',
    'web3_universal_aa': '^0.1.1+1',
    'web3_universal_reown': '^0.1.1',
    'web3_universal_swap': '^0.1.0+2',
    'web3_universal_price': '^0.1.1',
    'web3_universal_utxo': '^0.1.0+1',
    'web3_universal_bc_ur': '^0.1.0+1',
    'web3_universal_keystone': '^0.1.0+1',
    'web3_universal_ledger': '^0.1.0+1',
    'web3_universal_trezor': '^0.1.0+1',
    'web3_universal_mpc': '^0.1.0+1',
    'web3_universal_nft': '^0.1.1+1',
    'web3_universal_multicall': '^0.1.0+2',
    'web3_universal_mev': '^0.1.1',
    'web3_universal_staking': '^0.1.1+1',
    'web3_universal_history': '^0.1.1+1',
    'web3_universal_events': '^0.1.0+2',
    'web3_universal_solana': '^0.1.1',
    'web3_universal_bitcoin': '^0.1.1',
    'web3_universal_aptos': '^0.1.0',
    'web3_universal_ton': '^0.1.1',
    'web3_universal_tron': '^0.1.1',
    'web3_universal_polkadot': '^0.1.1',
    'web3_universal_cosmos': '^0.1.1',
    'web3_universal_debug': '^0.1.1',
    'web3_universal_bridge': '^0.1.0+2',
    'web3_universal_dapp': '^0.1.1+1',
    'web3_universal_compat': '^0.1.0',
}

def fix_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        new_lines = []
        modified = False
        skip_next = False
        
        for i, line in enumerate(lines):
            if skip_next:
                skip_next = False
                continue
            
            # Check if this line is a dependency definition that needs path removal
            # e.g. "  web3_universal_core:"
            stripped = line.strip()
            if stripped.endswith(':'):
                pkg_name = stripped[:-1]
                if pkg_name in replacements:
                    # Check next line for "path:"
                    if i + 1 < len(lines):
                        next_line = lines[i+1]
                        if 'path:' in next_line:
                            # It's a path dependency! Replace this line with version
                            # Preserve indentation
                            indent = line[:line.find(pkg_name)]
                            new_lines.append(f'{indent}{pkg_name}: {replacements[pkg_name]}\n')
                            skip_next = True # Skip the path line
                            modified = True
                            continue
            
            new_lines.append(line)
            
        if modified:
            with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
                f.writelines(new_lines)
            print(f"Fixed {file_path}")
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

for base_root in roots:
    for root, dirs, files in os.walk(base_root):
        if 'pubspec.yaml' in files:
            fix_file(os.path.join(root, 'pubspec.yaml'))
