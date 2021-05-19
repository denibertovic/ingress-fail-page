{ mkDerivation, fetchFromGitHub, base, bytestring, directory, filepath, hpack
, http-types, mime-types, rio, stdenv, text, unordered-containers
, wai, warp
}:
let
  gitignoreSrc = fetchFromGitHub {
    owner = "hercules-ci";
    repo = "gitignore";
    # put the latest commit sha of gitignore Nix library here:
    rev = "f9e996052b5af4032fe6150bba4a6fe4f7b9d698";
    # use what nix suggests in the mismatch message here:
    sha256 = "sha256:0jrh5ghisaqdd0vldbywags20m2cxpkbbk5jjjmwaw0gr8nhsafv";
  };
  inherit (import gitignoreSrc {}) gitignoreSource;
in
mkDerivation {
  pname = "ingress-fail-page";
  version = "0.1.0.0";
  src = gitignoreSource ../.;
  isLibrary = false;
  isExecutable = true;
  libraryToolDepends = [ hpack ];
  executableHaskellDepends = [
    base bytestring directory filepath http-types mime-types rio text
    unordered-containers wai warp
  ];
  prePatch = "hpack";
  homepage = "https://github.com/denibertovic/ingress-fail-page#readme";
  license = stdenv.lib.licenses.bsd3;
  doHaddock = false;
  enableSharedExecutables = false;
  enableLibraryProfiling = false;
}
