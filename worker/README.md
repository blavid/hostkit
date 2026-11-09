
## QR decode test dependency

`tests/qr.test.js` decodes the pairing QR PNG back to its URL with Python
(`zxing-cpp`, `pillow`, `opencv-python-headless`). Point `HOSTKIT_QR_PYTHON` at a
Python that has them; otherwise the test creates `/tmp/hostkit-qrvenv`, which
needs `python3 -m venv` (Debian/Ubuntu: the `python3-venv` package). CI installs
the decoder explicitly in the Worker tests job.
