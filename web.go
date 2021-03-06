package main

import (
	"database/sql"
	"fmt"
	"github.com/gorilla/mux"
	"golang.org/x/crypto/ssh"
	"gopkg.in/natefinch/lumberjack.v2"
	"net/http"
	"time"
)

type HandlerWithDBConnection struct {
	db *sql.DB
}

func startWebServer(bind, certFile, keyFile, sshAdvertise, assetsDir string, logger *lumberjack.Logger, hostPubkey ssh.PublicKey, db *sql.DB) {
	r := mux.NewRouter()

	r.Handle("/signin/{token}", &SigninConfirmationHandler{db: db, assetsDir: assetsDir}).Methods("GET")
	r.Handle("/signin/{token}", &SigninHandler{db: db}).Methods("POST")
	r.Handle("/signout", &SignoutHandler{db: db}).Methods("POST")
	r.Handle("/delete-account", &DeleteAccountHandler{db: db}).Methods("POST")

	homePaths := []string{"/", "/signin", "/throwaway", "/fingerprint"}
	for _, p := range homePaths {
		r.Handle(p, &HomeHandler{db: db, hostPubkey: hostPubkey, sshAdvertise: sshAdvertise, assetsDir: assetsDir}).Methods("GET")
	}

	r.Handle("/pins.csv", &PinsHandler{db: db}).Methods("GET")
	r.Handle("/pin", &UpdatePinHandler{db: db}).Methods("POST")

	r.Handle("/how", &HowHandler{assetsDir: assetsDir}).Methods("GET")

	r.PathPrefix("/").Handler(http.FileServer(http.Dir(assetsDir)))

	var handler http.Handler = r
	if logger != nil {
		handler = http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
			timeStr := time.Now().UTC().Format("2006-01-02 15:04:05")
			fmt.Fprintf(logger, "%s %s %s %s\n", timeStr, req.RemoteAddr, req.Method, req.URL)
			r.ServeHTTP(resp, req)
		})
	}

	go func() {
		err := http.ListenAndServeTLS(bind, certFile, keyFile, handler)
		if err != nil {
			fmt.Println(err)
		}
	}()
}
