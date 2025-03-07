{ lib
, stdenv
, python
, buildPythonPackage
, fetchFromGitHub
, alembic
, argcomplete
, attrs
, blinker
, cached-property
, cattrs
, clickclick
, colorlog
, connexion
, cron-descriptor
, croniter
, cryptography
, dataclasses
, deprecated
, dill
, flask
, flask_login
, flask-appbuilder
, flask-caching
, flask-session
, flask-wtf
, GitPython
, graphviz
, gunicorn
, httpx
, iso8601
, importlib-resources
, importlib-metadata
, inflection
, itsdangerous
, jinja2
, jsonschema
, lazy-object-proxy
, linkify-it-py
, lockfile
, markdown
, markupsafe
, marshmallow-oneofschema
, mdit-py-plugins
, numpy
, openapi-spec-validator
, pandas
, pathspec
, pendulum
, psutil
, pygments
, pyjwt
, python-daemon
, python-dateutil
, python-nvd3
, python-slugify
, python3-openid
, pythonOlder
, pyyaml
, rich
, setproctitle
, sqlalchemy
, sqlalchemy-jsonfield
, swagger-ui-bundle
, tabulate
, tenacity
, termcolor
, typing-extensions
, unicodecsv
, werkzeug
, pytestCheckHook
, freezegun
, mkYarnPackage
, writeScript

# Extra airflow providers to enable
, enabledProviders ? []
}:
let
  version = "2.3.4";

  airflow-src = fetchFromGitHub rec {
    owner = "apache";
    repo = "airflow";
    rev = "refs/tags/${version}";
    # Required because the GitHub archive tarballs don't appear to include tests
    leaveDotGit = true;
    sha256 = "sha256-rxvLyz/hvZ6U8QKy9MiVofU0qeeo7OHctAj2PkxLh2c=";
  };

  # airflow bundles a web interface, which is built using webpack by an undocumented shell script in airflow's source tree.
  # This replicates this shell script, fixing bugs in yarn.lock and package.json

  airflow-frontend = mkYarnPackage {
    name = "airflow-frontend";

    src = "${airflow-src}/airflow/www";
    packageJSON = ./package.json;
    yarnLock = ./yarn.lock;
    yarnNix = ./yarn.nix;

    distPhase = "true";

    # The webpack license plugin tries to create /licenses when given the
    # original relative path
    postPatch = ''
      sed -i 's!../../../../licenses/LICENSES-ui.txt!licenses/LICENSES-ui.txt!' webpack.config.js
    '';

    configurePhase = ''
      cp -r $node_modules node_modules
    '';

    buildPhase = ''
      yarn --offline build
      find package.json yarn.lock static/css static/js -type f | sort | xargs md5sum > static/dist/sum.md5
    '';

    installPhase = ''
      mkdir -p $out/static/
      cp -r static/dist $out/static
    '';
  };

  # Import generated file with metadata for provider dependencies and imports.
  # Enable additional providers using enabledProviders above.
  providers = import ./providers.nix;
  getProviderDeps = provider: map (dep: python.pkgs.${dep}) providers.${provider}.deps;
  getProviderImports = provider: providers.${provider}.imports;
  providerDependencies = lib.concatMap getProviderDeps enabledProviders;
  providerImports = lib.concatMap getProviderImports enabledProviders;
in
buildPythonPackage rec {
  pname = "apache-airflow";
  inherit version;
  src = airflow-src;

  disabled = pythonOlder "3.6";

  propagatedBuildInputs = [
    alembic
    argcomplete
    attrs
    blinker
    cached-property
    cattrs
    clickclick
    colorlog
    connexion
    cron-descriptor
    croniter
    cryptography
    deprecated
    dill
    flask
    flask-appbuilder
    flask-caching
    flask-session
    flask-wtf
    flask_login
    GitPython
    graphviz
    gunicorn
    httpx
    iso8601
    importlib-resources
    inflection
    itsdangerous
    jinja2
    jsonschema
    lazy-object-proxy
    linkify-it-py
    lockfile
    markdown
    markupsafe
    marshmallow-oneofschema
    mdit-py-plugins
    numpy
    openapi-spec-validator
    pandas
    pathspec
    pendulum
    psutil
    pygments
    pyjwt
    python-daemon
    python-dateutil
    python-nvd3
    python-slugify
    python3-openid
    pyyaml
    rich
    setproctitle
    sqlalchemy
    sqlalchemy-jsonfield
    swagger-ui-bundle
    tabulate
    tenacity
    termcolor
    typing-extensions
    unicodecsv
    werkzeug
  ] ++ lib.optionals (pythonOlder "3.7") [
    dataclasses
  ] ++ lib.optionals (pythonOlder "3.9") [
    importlib-metadata
  ] ++ providerDependencies;

  buildInputs = [
    airflow-frontend
  ];

  checkInputs = [
    freezegun
    pytestCheckHook
  ];

  # By default, source code of providers is included but unusable due to missing
  # transitive dependencies. To enable a provider, add it to extraProviders
  # above
  INSTALL_PROVIDERS_FROM_SOURCES = "true";

  postPatch = ''
    substituteInPlace setup.cfg \
      --replace "colorlog>=4.0.2, <5.0" "colorlog" \
      --replace "flask-login>=0.6.2" "flask-login"
  '' + lib.optionalString stdenv.isDarwin ''
    # Fix failing test on Hydra
    substituteInPlace airflow/utils/db.py \
      --replace "/tmp/sqlite_default.db" "$TMPDIR/sqlite_default.db"
  '';

  # allow for gunicorn processes to have access to Python packages
  makeWrapperArgs = [
    "--prefix PYTHONPATH : $PYTHONPATH"
  ];

  pythonImportsCheck = [
    "airflow"
  ] ++ providerImports;

  checkPhase = ''
    export HOME=$(mktemp -d)
    export AIRFLOW_HOME=$HOME
    export AIRFLOW__CORE__UNIT_TEST_MODE=True
    export AIRFLOW_DB="$HOME/airflow.db"
    export PATH=$PATH:$out/bin

    airflow version
    airflow db init
    airflow db reset -y
  '';

  pytestFlagsArray = [
    "tests/core/test_core.py"
  ];

  disabledTests = lib.optionals stdenv.isDarwin [
    "bash_operator_kill" # psutil.AccessDenied
  ];

  postInstall = ''
    cp -rv ${airflow-frontend}/static/dist $out/lib/${python.libPrefix}/site-packages/airflow/www/static
  '';

  # Updates yarn.lock and package.json
  passthru.updateScript = writeScript "update.sh" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p common-updater-scripts curl pcre "python3.withPackages (ps: with ps; [ pyyaml ])" yarn2nix

    set -euo pipefail

    # Get new version
    new_version="$(curl -s https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html |
      pcregrep -o1 'Airflow ([0-9.]+).' | head -1)"
    update-source-version ${pname} "$new_version"

    # Update frontend
    cd ./pkgs/development/python-modules/apache-airflow
    curl -O https://raw.githubusercontent.com/apache/airflow/$new_version/airflow/www/yarn.lock
    curl -O https://raw.githubusercontent.com/apache/airflow/$new_version/airflow/www/package.json
    # Note: for 2.3.4 a manual change was needed to get a fully resolved URL for
    # caniuse-lite@1.0.30001312 (with the sha after the #). The error from yarn
    # was 'Can't make a request in offline mode' from yarn. Corrected install by
    # manually running yarn add caniuse-lite@1.0.30001312 and copying the
    # requisite section from the generated yarn.lock.
    yarn2nix > yarn.nix

    # update provider dependencies
    ./update-providers.py
  '';

  meta = with lib; {
    description = "Programmatically author, schedule and monitor data pipelines";
    homepage = "https://airflow.apache.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ bhipple gbpdt ingenieroariel ];
  };
}
