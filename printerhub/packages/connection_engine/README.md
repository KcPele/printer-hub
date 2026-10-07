# connection_engine

Finds out what a device on the network is and what it can do.

- `DeviceProbe.probe(address)` asks an address for IPP and eSCL at the same time and describes what answered: maker, model, what it prints, what it scans, how to reach it, and what it is doing.
- `DeviceProbe.status(connections)` reads what a known device is doing. A device that does not answer is `unreachable`, never an exception.
- `CertificateTrust` remembers the certificate each device showed first, and refuses a different one later.

Pure Dart. `dart test --tags simulator` probes `backend/simulator`.
