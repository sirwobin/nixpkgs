{ lib
, buildPythonPackage
, fetchPypi

# extras: babel
, babel
, flask-babel

# extras: common
, bcrypt
, bleach
, flask-mailman
, qrcode

# extras: fsqla
, flask-sqlalchemy
, sqlalchemy
, sqlalchemy-utils

# extras: mfa
, cryptography
, phonenumbers

# propagates
, blinker
, email-validator
, flask
, flask_login
, flask_principal
, flask-wtf
, itsdangerous
, passlib

# tests
, argon2-cffi
, flask-mongoengine
, mongoengine
, mongomock
, peewee
, pony
, pytestCheckHook
, python-dateutil
, zxcvbn
}:

buildPythonPackage rec {
  pname = "flask-security-too";
  version = "5.0.1";

  src = fetchPypi {
    pname = "Flask-Security-Too";
    inherit version;
    sha256 = "sha256-Q247oFmE8BDid0EFXGm8EsxFVmlG5NgFmQomKMNlZZQ=";
  };

  propagatedBuildInputs = [
    blinker
    email-validator
    flask
    flask_login
    flask_principal
    flask-wtf
    itsdangerous
    passlib
  ];

  passthru.optional-dependencies = {
    babel = [
      babel
      flask-babel
    ];
    common = [
      bcrypt
      bleach
      flask-mailman
      qrcode
    ];
    fsqla = [
      flask-sqlalchemy
      sqlalchemy
      sqlalchemy-utils
    ];
    mfa = [
      cryptography
      phonenumbers
    ];
  };

  checkInputs = [
    argon2-cffi
    flask-mongoengine
    mongoengine
    mongomock
    peewee
    pony
    pytestCheckHook
    python-dateutil
    zxcvbn
  ]
  ++ passthru.optional-dependencies.babel
  ++ passthru.optional-dependencies.common
  ++ passthru.optional-dependencies.fsqla
  ++ passthru.optional-dependencies.mfa;


  pythonImportsCheck = [ "flask_security" ];

  meta = with lib; {
    homepage = "https://pypi.org/project/Flask-Security-Too/";
    description = "Simple security for Flask apps (fork)";
    license = licenses.mit;
    maintainers = with maintainers; [ gador ];
  };
}
