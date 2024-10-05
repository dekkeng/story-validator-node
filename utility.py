#!/usr/bin/env python3

import requests
import json
import argparse
from tabulate import tabulate
from colorama import Fore, Style, init

# Initialize colorama for cross-platform colored output
init()

class StoryValidatorUtility:
    def __init__(self, rpc_url):
        self.rpc_url = rpc_url

    def make_request(self, method, params=None):
        headers = {'Content-Type': 'application/json'}
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params or []
        }
        response = requests.post(self.rpc_url, headers=headers, data=json.dumps(payload))
        return response.json()['result']

    def get_node_info(self):
        return self.make_request("status")

    def get_validators(self):
        return self.make_request("validators")

    def get_peers(self):
        return self.make_request("net_info")

    def get_latest_block(self):
        return self.make_request("block")

    def get_syncing_status(self):
        return self.make_request("syncing")

    def print_node_info(self):
        info = self.get_node_info()
        print(f"{Fore.GREEN}Node Information:{Style.RESET_ALL}")
        print(f"Node ID: {info['node_info']['id']}")
        print(f"Moniker: {info['node_info']['moniker']}")
        print(f"Network: {info['node_info']['network']}")
        print(f"Latest Block Height: {info['sync_info']['latest_block_height']}")
        print(f"Catching Up: {info['sync_info']['catching_up']}")

    def print_validators(self):
        validators = self.get_validators()['validators']
        print(f"\n{Fore.GREEN}Validators:{Style.RESET_ALL}")
        table_data = [
            [v['address'][:10] + '...', v['voting_power'], v['proposer_priority']]
            for v in validators
        ]
        headers = ["Address", "Voting Power", "Proposer Priority"]
        print(tabulate(table_data, headers=headers, tablefmt="grid"))

    def print_peers(self):
        peers = self.get_peers()['peers']
        print(f"\n{Fore.GREEN}Connected Peers:{Style.RESET_ALL}")
        table_data = [
            [p['node_info']['id'][:10] + '...', p['node_info']['moniker'], p['remote_ip']]
            for p in peers
        ]
        headers = ["Node ID", "Moniker", "IP Address"]
        print(tabulate(table_data, headers=headers, tablefmt="grid"))

    def print_latest_block(self):
        block = self.get_latest_block()['block']
        print(f"\n{Fore.GREEN}Latest Block Information:{Style.RESET_ALL}")
        print(f"Height: {block['header']['height']}")
        print(f"Hash: {block['header']['last_block_id']['hash']}")
        print(f"Proposer: {block['header']['proposer_address']}")
        print(f"Number of Transactions: {len(block['data']['txs'])}")

    def print_syncing_status(self):
        syncing = self.get_syncing_status()
        status = "Syncing" if syncing else "Not Syncing"
        color = Fore.YELLOW if syncing else Fore.GREEN
        print(f"\n{Fore.GREEN}Syncing Status:{Style.RESET_ALL} {color}{status}{Style.RESET_ALL}")

    def run_health_check(self):
        print(f"{Fore.CYAN}Running Health Check...{Style.RESET_ALL}")
        self.print_node_info()
        self.print_syncing_status()
        self.print_latest_block()
        self.print_validators()
        self.print_peers()

def main():
    parser = argparse.ArgumentParser(description="Story Blockchain Validator Utility")
    parser.add_argument("--rpc", default="http://localhost:26657", help="RPC endpoint URL")
    parser.add_argument("--action", choices=["health", "node", "validators", "peers", "block", "sync"],
                        default="health", help="Action to perform")
    args = parser.parse_args()

    utility = StoryValidatorUtility(args.rpc)

    actions = {
        "health": utility.run_health_check,
        "node": utility.print_node_info,
        "validators": utility.print_validators,
        "peers": utility.print_peers,
        "block": utility.print_latest_block,
        "sync": utility.print_syncing_status
    }

    actions[args.action]()

if __name__ == "__main__":
    main()