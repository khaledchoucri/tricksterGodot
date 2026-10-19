"""Where the reverse-engineering tools find things. Override any of these
with an environment variable of the same name."""
import os

# The original client's executable (the 2019 client).
TRICKSTER_BIN = os.environ.get('TRICKSTER_BIN', r'C:\Users\Khaled\Downloads\Playtrickster_05282019\Trickster.bin')
# Ghidra 12.1.x and the JDK 21 it runs on (REA's Ghidra provider needs both).
GHIDRA_INSTALL_DIR = os.environ.get('GHIDRA_INSTALL_DIR', r'C:\Users\Khaled\tools\ghidra_12.1.4_PUBLIC')
JAVA_HOME = os.environ.get('JAVA_HOME', r'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot')
# Scratch space for queues, dumps and Ghidra projects (never committed).
WORK = os.environ.get('RE_WORK', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'work'))
