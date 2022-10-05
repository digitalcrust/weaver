# Dump types to typescript file
all:
	poetry run pydantic2ts --module ./output_schemas/detrital_zircon.py --output ./types.ts