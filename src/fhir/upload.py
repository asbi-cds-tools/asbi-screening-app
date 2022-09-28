#!/usr/bin/env python3
"""Util to upload all given, or available FHIR resources to the given FHIR server"""
import json
import os
import requests
import argparse


def setup_args():
    # Usage message is the module's docstring.

    parser = argparse.ArgumentParser(epilog=__doc__)
    parser.add_argument("--verbose", action="store_true", help="increase verbosity")
    parser.add_argument(
        "fhir_server_url", action="store", nargs=1, help="FHIR server base URL"
    )
    parser.add_argument(
        "fhir_files",
        action="store",
        nargs="*",
        default=None,
        help="fhir JSON files to upload",
    )
    args = parser.parse_args()
    return args


def find_files(path):
    """Find all possible FHIR files in the script path"""
    for fname in (
        fname for fname in os.scandir(path) if fname.name.lower().endswith(".json")
    ):
        yield fname


def bundle_files(fhir_resources):
    """Combine individual FHIR resources into a single transaction Bundle"""
    tx_bundle = {
        "resourceType": "Bundle",
        # "id": "TBD",
        "type": "transaction",
        "entry": [],
    }

    for fhir_resource in fhir_resources:
        if "id" not in fhir_resource:
            print("resource ID missing; skipping: ", fhir_resource)
            continue

        resource_skel = {"request": {"method": "PUT", "url": ""}, "resource": {}}

        resource_skel.update(
            {
                "request": {
                    "url": "{}/{}".format(
                        fhir_resource["resourceType"], fhir_resource["id"]
                    ),
                    "method": "PUT",
                },
                "resource": fhir_resource,
            }
        )

        tx_bundle["entry"].append(resource_skel)
    return tx_bundle


def load_files(fhir_url, fhir_files):
    fhir_resources = []
    for fhir_file in fhir_files:
        with open(fhir_file, "r") as fhir:
            try:
                resource = json.loads(fhir.read())
            except json.decoder.JSONDecodeError as je:
                print(f"{fhir_file.path} contains invalid JSON")
                exit(1)
        fhir_resources.append(resource)
    tx_bundle = bundle_files(fhir_resources)
    response = requests.post(fhir_url, json=tx_bundle, timeout=30)
    print(response.content)
    response.raise_for_status()


def main():
    print("started")
    args = setup_args()

    script_path = os.path.dirname(os.path.realpath(__file__))

    print(args)
    fhir_files = args.fhir_files or set(find_files(script_path))
    load_files(args.fhir_server_url[0], fhir_files)


# run script if invoked directly
if __name__ == "__main__":
    main()
