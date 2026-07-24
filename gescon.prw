// gescon.prw — ponto de entrada do GesCon. `advplc serve gescon.prw` sobe
// a UI web; esta função abre o cadastro de Unidades como tela inicial
// (menu de navegação entre módulos fica pra Plano 2, junto com login).
#include "totvs.ch"
#include "src/unidades.prw"

User Function GesCon()
    ConOut("GesCon — Sistema de Gestão Condominial")
    GcUnidades()
Return
