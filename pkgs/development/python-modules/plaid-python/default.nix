{ lib
, buildPythonPackage
, fetchPypi
, nulltype
, python-dateutil
, urllib3
, pythonOlder
}:

buildPythonPackage rec {
  pname = "plaid-python";
  version = "10.0.0";
  format = "setuptools";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-dhFc4QCvWrb4gYdMaNlaCRaRrWsuUY+leTkoEhFHHds=";
  };

  propagatedBuildInputs = [
    nulltype
    python-dateutil
    urllib3
  ];

  # Tests require a Client IP
  doCheck = false;

  pythonImportsCheck = [
    "plaid"
  ];

  meta = with lib; {
    description = "Python client library for the Plaid API and Link";
    homepage = "https://github.com/plaid/plaid-python";
    changelog = "https://github.com/plaid/plaid-python/blob/master/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ bhipple ];
  };
}
