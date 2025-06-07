import arkit
import sys
import os
import argparse
import shutil
import struct
from collections import OrderedDict
from time import gmtime, strftime

debug = False

time = strftime("%Y-%m-%d--%H-%M-%S", gmtime())
log_dir = os.path.join(os.getcwd(), str(time))


def create_log_dir():
    os.makedirs(log_dir)


if debug:
    create_log_dir()


def log(mes, id=1):
    if debug:
        if id == 1:
            print("mod install: " + mes)
        else:
            print(mes)
            log_file = os.path.join(log_dir, id)
            if not os.path.isfile(log_file):
                open(log_file, "x")
            with open(log_file, "a") as file:
                if file.writable():
                    file.write(mes)


class ArkModInstaller:
    def __init__(self, working_dir, modid, modname=False, install_dir=None):
        self.working_dir = working_dir
        self.modid = modid
        self.modname = modname
        self.install_dir = install_dir or working_dir
        self.map_names = []
        self.meta_data = OrderedDict([])

    def install_mod(self):
        """
        Install a single mod
        """
        log(f"[+] Starting to install mod {self.modid}")

        if not self.extract_mod():
            log(f"[x] Failed to install mod {self.modid}")
            return False

        log(f"[+] Successfully installed mod {self.modid}")
        return True

    def extract_mod(self):
        """
        Extract .z files and install mod
        """
        log("[+] Extracting .z files")

        def f(file, name, curdir):
            src = os.path.join(curdir, file)
            dst = os.path.join(curdir, name)
            uncompressed = os.path.join(curdir, file + ".uncompressed_size")
            arkit.unpack(src, dst)
            # log("[+] 已解压 " + file)
            os.remove(src)
            if os.path.isfile(uncompressed):
                os.remove(uncompressed)

        try:
            mod_path = os.path.join(
                self.working_dir,
                "steamapps",
                "workshop",
                "content",
                "346110",
                self.modid,
                "WindowsNoEditor",
            )
            for curdir, subdirs, files in os.walk(mod_path):
                for file in files:
                    name, ext = os.path.splitext(file)
                    if ext == ".z":
                        f(file, name, curdir)

        except (
            arkit.UnpackException,
            arkit.SignatureUnpackException,
            arkit.CorruptUnpackException,
        ) as e:
            log("[x] Failed to extract .z files")
            log(str(e))
            return False

        if self.create_mod_file():
            if self.move_mod():
                return True
            else:
                log("Failed to move mod files")
                return False
        return False

    def move_mod(self):
        """
        Move mod from SteamCMD download location to ARK server
        """
        ark_mod_folder = os.path.join(
            self.install_dir, "ShooterGame", "Content", "Mods"
        )
        output_dir = os.path.join(ark_mod_folder, str(self.modid))
        source_dir = os.path.join(
            self.working_dir,
            "steamapps",
            "workshop",
            "content",
            "346110",
            self.modid,
            "WindowsNoEditor",
        )

        if not os.path.isdir(ark_mod_folder):
            log("[+] Creating directory: " + ark_mod_folder)
            os.mkdir(ark_mod_folder)

        if os.path.isdir(output_dir):
            shutil.rmtree(output_dir)

        log("[+] Moving mod files to: " + output_dir)
        shutil.copytree(source_dir, output_dir)

        if self.modname:
            log("Creating mod name file")
            self.create_mod_name_txt(ark_mod_folder)

        return True

    def create_mod_name_txt(self, mod_folder):
        with open(os.path.join(mod_folder, self.map_names[0] + ".txt"), "w+") as f:
            f.write(self.modid)

    def create_mod_file(self):
        """
        Create .mod file
        """
        if not self.parse_base_info() or not self.parse_meta_data():
            return False

        log("[+] Writing .mod file")
        mod_file_path = os.path.join(
            self.install_dir, "ShooterGame", "Content", "Mods", f"{self.modid}.mod"
        )

        with open(mod_file_path, "w+b") as f:
            modid = int(self.modid)
            f.write(struct.pack("Ixxxx", modid))
            self.write_ue4_string("modName", f)
            self.write_ue4_string("", f)

            map_count = len(self.map_names)
            f.write(struct.pack("i", map_count))

            for m in self.map_names:
                self.write_ue4_string(m, f)

            num2 = 4280483635
            f.write(struct.pack("I", num2))
            num3 = 2
            f.write(struct.pack("i", num3))

            if "modType" in self.meta_data:
                mod_type = b"1"
            else:
                mod_type = b"0"

            f.write(struct.pack("p", mod_type))
            meta_length = len(self.meta_data)
            f.write(struct.pack("i", meta_length))

            for k, v in self.meta_data.items():
                self.write_ue4_string(k, f)
                self.write_ue4_string(v, f)

        return True

    def read_ue4_string(self, file):
        count = struct.unpack("i", file.read(4))[0]
        flag = False
        if count < 0:
            flag = True
            count -= 1

        if flag or count <= 0:
            return ""

        return file.read(count)[:-1].decode()

    def write_ue4_string(self, string_to_write, file):
        string_length = len(string_to_write) + 1
        file.write(struct.pack("i", string_length))
        barray = bytearray(string_to_write, "utf-8")
        file.write(barray)
        file.write(struct.pack("p", b"0"))

    def parse_meta_data(self):
        """
        Parse modmeta.info file
        """
        log("[+] Collecting mod metadata from modmeta.info")

        mod_meta = os.path.join(
            self.working_dir,
            "steamapps",
            "workshop",
            "content",
            "346110",
            self.modid,
            r"WindowsNoEditor",
            r"modmeta.info",
        )
        if not os.path.isfile(mod_meta):
            log("[x] modmeta.info file not found")
            return False

        with open(mod_meta, "rb") as f:
            total_pairs = struct.unpack("i", f.read(4))[0]

            for i in range(total_pairs):
                key, value = "", ""

                key_bytes = struct.unpack("i", f.read(4))[0]
                key_flag = False
                if key_bytes < 0:
                    key_flag = True
                    key_bytes -= 1

                if not key_flag and key_bytes > 0:
                    raw = f.read(key_bytes)
                    key = raw[:-1].decode()

                value_bytes = struct.unpack("i", f.read(4))[0]
                value_flag = False
                if value_bytes < 0:
                    value_flag = True
                    value_bytes -= 1

                if not value_flag and value_bytes > 0:
                    raw = f.read(value_bytes)
                    value = raw[:-1].decode()

                if key and value:
                    log("[!] " + key + ":" + value)
                    self.meta_data[key] = value

        return True

    def parse_base_info(self):
        """
        Parse mod.info file
        """
        log("[+] Collecting mod details from mod.info")

        mod_info = os.path.join(
            self.working_dir,
            "steamapps",
            "workshop",
            "content",
            "346110",
            self.modid,
            r"WindowsNoEditor",
            r"mod.info",
        )

        if not os.path.isfile(mod_info):
            log("[x] mod.info file not found")
            return False

        with open(mod_info, "rb") as f:
            self.read_ue4_string(f)
            map_count = struct.unpack("i", f.read(4))[0]

            for i in range(map_count):
                cur_map = self.read_ue4_string(f)
                if cur_map:
                    self.map_names.append(cur_map)

        return True


def main():
    parser = argparse.ArgumentParser(description="ARK Mod Installer")
    parser.add_argument(
        "--workingdir", required=True, dest="workingdir", help="Game server directory"
    )
    parser.add_argument(
        "--modid", required=True, dest="modid", help="Mod ID to install"
    )
    parser.add_argument(
        "--namefile",
        default=None,
        action="store_true",
        dest="modname",
        help="Create .name file containing mod text name",
    )
    parser.add_argument(
        "--installdir",
        dest="installdir",
        help="Mod installation directory, if not specified will use workingdir",
    )
    args = parser.parse_args()

    installer = ArkModInstaller(
        args.workingdir, args.modid, args.modname, args.installdir
    )
    if not installer.install_mod():
        sys.exit(1)


if __name__ == "__main__":
    main()
