{ lib
, fetchurl
, nixosTests
, python3
, ghostscript
, imagemagickBig
, jbig2enc
, optipng
, pngquant
, qpdf
, tesseract5
, unpaper
, liberation_ttf
, fetchFromGitHub
}:

let
  # Use specific package versions required by paperless-ngx
  python = python3.override {
    packageOverrides = self: super: {
      django = super.django_4;

      # use paperless-ngx version of django-q
      # see https://github.com/paperless-ngx/paperless-ngx/pull/1014
      django-q = super.django-q.overridePythonAttrs (oldAttrs: rec {
        src = fetchFromGitHub {
          owner = "paperless-ngx";
          repo = "django-q";
          hash = "sha256-alu7tZwUn77xhUF9c/aGmwRwO//mR/FucXjvXUl/6ek=";
          rev = "8b5289d8caf36f67fb99448e76ead20d5b498c1b";
        };
        # due to paperless-ngx modification of the pyproject.toml file
        # the patch is not needed any more
        patches = [ ];
      });

      aioredis = super.aioredis.overridePythonAttrs (oldAttrs: rec {
        version = "1.3.1";
        src = oldAttrs.src.override {
          inherit version;
          sha256 = "0fi7jd5hlx8cnv1m97kv9hc4ih4l8v15wzkqwsp73is4n0qazy0m";
        };
      });

      eth-keys = super.eth-keys.overridePythonAttrs (_: {
        doCheck = false;
      });
    };
  };

  path = lib.makeBinPath [
    ghostscript
    imagemagickBig
    jbig2enc
    optipng
    pngquant
    qpdf
    tesseract5
    unpaper
  ];
in
python.pkgs.pythonPackages.buildPythonApplication rec {
  pname = "paperless-ngx";
  version = "1.9.1";

  # Fetch the release tarball instead of a git ref because it contains the prebuilt fontend
  src = fetchurl {
    url = "https://github.com/paperless-ngx/paperless-ngx/releases/download/v${version}/${pname}-v${version}.tar.xz";
    hash = "sha256-KWq3zUES8klXexNO9krlqZKZEajOhkTHF13t/3rxrPc=";
  };

  format = "other";

  propagatedBuildInputs = with python.pkgs.pythonPackages; [
    aioredis
    arrow
    asgiref
    async-timeout
    attrs
    autobahn
    automat
    blessed
    certifi
    cffi
    channels-redis
    channels
    chardet
    click
    coloredlogs
    concurrent-log-handler
    constantly
    cryptography
    daphne
    dateparser
    django-cors-headers
    django-extensions
    django-filter
    django-picklefield
    django-q
    django
    djangorestframework
    filelock
    fuzzywuzzy
    gunicorn
    h11
    hiredis
    httptools
    humanfriendly
    hyperlink
    idna
    imap-tools
    img2pdf
    incremental
    inotify-simple
    inotifyrecursive
    joblib
    langdetect
    pkgs.libmysqlclient
    lxml
    msgpack
    numpy
    ocrmypdf
    pathvalidate
    pdf2image
    pdfminer-six
    pikepdf
    pillow
    pluggy
    portalocker
    psycopg2
    pyasn1-modules
    pyasn1
    pycparser
    pyopenssl
    python-dateutil
    python-dotenv
    python-gnupg
    python-Levenshtein
    python-magic
    pytz
    pyyaml
    pyzbar
    redis
    regex
    reportlab
    requests
    scikit-learn
    scipy
    service-identity
    six
    sortedcontainers
    sqlparse
    threadpoolctl
    tika
    tqdm
    twisted.optional-dependencies.tls
    txaio
    tzlocal
    urllib3
    uvicorn
    uvloop
    watchdog
    watchgod
    wcwidth
    websockets
    whitenoise
    whoosh
    zope_interface
  ];

  # paperless-ngx includes the bundled django-q version. This will
  # conflict with the tests and is not needed since we overrode the
  # django-q version with the paperless-ngx version
  postPatch = ''
    rm -rf src/django-q
  '';

  # Compile manually because `pythonRecompileBytecodeHook` only works for
  # files in `python.sitePackages`
  postBuild = ''
    ${python.interpreter} -OO -m compileall src
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp -r . $out/lib/paperless-ngx
    chmod +x $out/lib/paperless-ngx/src/manage.py
    makeWrapper $out/lib/paperless-ngx/src/manage.py $out/bin/paperless-ngx \
      --prefix PYTHONPATH : "$PYTHONPATH" \
      --prefix PATH : "${path}"
  '';

  checkInputs = with python.pkgs.pythonPackages; [
    pytest-django
    pytest-env
    pytest-sugar
    pytest-xdist
    factory_boy
    pytestCheckHook
  ];

  pytestFlagsArray = [ "src" ];

  # The tests require:
  # - PATH with runtime binaries
  # - A temporary HOME directory for gnupg
  # - XDG_DATA_DIRS with test-specific fonts
  preCheck = ''
    export PATH="${path}:$PATH"
    export HOME=$(mktemp -d)
    export XDG_DATA_DIRS="${liberation_ttf}/share:$XDG_DATA_DIRS"

    # Disable unneeded code coverage test
    substituteInPlace src/setup.cfg \
      --replace "--cov --cov-report=html" ""
  '';

  passthru = {
    inherit python path;
    tests = { inherit (nixosTests) paperless; };
  };

  meta = with lib; {
    description = "A supercharged version of paperless: scan, index, and archive all of your physical documents";
    homepage = "https://paperless-ngx.readthedocs.io/en/latest/";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ lukegb gador erikarvstedt ];
  };
}
