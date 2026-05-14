package main

import (
    "os"

    "github.com/cosmos/cosmos-sdk/server"
    svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
    "github.com/dlesp/dlesp/app"
)

func main() {
    rootCmd, _ := app.NewRootCmd()
    if err := svrcmd.Execute(rootCmd, "", app.DefaultNodeHome); err != nil {
        os.Exit(1)
    }
}
