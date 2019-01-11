# spiffe-hsm-poc
## SoftHSM
### Dependencies
```
$ sudo apt-get install autoconf automake pkg-config  libtool 
$ sudo apt-get install openssl
$ sudo apt-get install libssl-dev
$ sudo apt-get install sqlite
$ sudo apt-get install libp11-kit-dev
$ sudo apt-get install libcppunit-dev
```
### Installation
1. Clone 
```
$ git clone https://github.com/opendnssec/SoftHSMv2.git
$ cd ./SoftHSMv2
```
2. Configure
```
$ sh ./autogen.sh
$ ./configure --disable-gost
```
3. Compile
```
$ make
```
4. Unit tests
```
$ make check
```
5. Install Library
```
$ sudo make install
```
### Проверка

Если запустить команду 
```
softhsm2-util --show-slots
``` 
появится список всех инициализированных токенов.


## Go implementation of the PKCS#11 API (ThalesIgnite/crypto11)

### Dependencies
```
$ go get -u github.com/golang/dep/cmd/dep
```
### Installation
1. Clone
```
$ go get github.com/ThalesIgnite/crypto11
$ cd $GOPATH/src/github.com/ThalesIgnite/crypto11
```
2. Ensure deps
```
$ dep ensure
```
3. Build
```
$ go build
```
4. Configure

Перед начало конфигурации необходимо проверить где расположен файл `libsofthsm2.so`. Либо он расположен по пути 
```
usr/lib/softhsm/libsofthsm2.so
```
если там его не оказалось, то необходимо проверить следующий путь
```
usr/local/lib/softhsm/ibsofthsm2.so
```
В соотвествии с расположением файла выполняется конфигурация:
Исправить файл `config`
```
{
    "Path": "/usr/local/lib/softhsm/libsofthsm2.so",
    "TokenLabel": "test",
    "Pin": "password"
}
```

Стандартное расположение конфигурационного файла `softhsm2.conf` для `softhsm` это `/etc/softhsm2.conf`. В этом файле указывается путь до директории, где будут храниться токены. 
Для запуска данного примера можно создать свой конфигурационный файл и указать в нем другой путь до директории токенов. Для этого необходимо создать в текущей директории файл `softhsm.conf` и поместить в него следующие данные:
```
$ cat softhsm2.conf
directories.tokendir = /go/src/github.com/ThalesIgnite/crypto11/tokens
objectstore.backend = file
log.level = INFO
$ export SOFTHSM2_CONF=$PWD/softhsm2.conf
```
5. Initialize Tokens
```
$ softhsm2-util --init-token --slot 0 --label test
``` 
При инциализации использовать пароль указанный в файле `config`.

6. Test
```
$ go test -count=1
```

## Go implementation of the PKCS#11 API (miekg/pkcs11)
### Example
1. Configure 
```
$ export SOFTHSM_CONF=$PWD/softhsm2.conf
```
2. Initialize Token 

Можно использовать уже инциализированный токен, для этого необохдимо в файле `example.go` поменять пароль на тот, что использован при ницализации. То есть пароль при инциализации токена должен соответствоать паролю в `example.go`
```
$ softhsm2-utill --init-token --slot 0 --label test --pin password
```
3. Use `libsofthsm2.so` as the pkcs11 module:
```
p := pkcs11.New("/usr/lib/softhsm/libsofthsm2.so")
```
Здесь тоже необходимо учитывать расположение `libsofthsm2.so`

4. Run example
```
$ go run example.go
```

### Содержание файла example.go
```
package main

import (
	"fmt"

	"github.com/miekg/pkcs11"
)

func main() {
	p := pkcs11.New("/usr/local/lib/softhsm/libsofthsm2.so")
	err := p.Initialize()
	if err != nil {
		panic(err)
	}

	defer p.Destroy()
	defer p.Finalize()

	slots, err := p.GetSlotList(true)
	if err != nil {
		panic(err)
	}

	session, err := p.OpenSession(slots[0], pkcs11.CKF_SERIAL_SESSION|pkcs11.CKF_RW_SESSION)
	if err != nil {
		panic(err)
	}
	defer p.CloseSession(session)

	err = p.Login(session, pkcs11.CKU_USER, "password")
	if err != nil {
		panic(err)
	}
	defer p.Logout(session)

	p.DigestInit(session, []*pkcs11.Mechanism{pkcs11.NewMechanism(pkcs11.CKM_SHA_1, nil)})
	hash, err := p.Digest(session, []byte("this is a string"))
	if err != nil {
		panic(err)
	}

	for _, d := range hash {
		fmt.Printf("%x", d)
	}
	fmt.Println()
}
```
