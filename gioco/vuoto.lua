-- =====================================================================
--  design.lua  ·  IL VOSTRO GIOCO (da zero)
--  1 · scrivete il messaggio   2 · scegliete le meccaniche   3 · scrivete la storia
--  {nome} = protagonista · {opinione} = ultima opinione · {umore} = valore di una grandezza
-- =====================================================================
return {
  titolo = "Il nostro gioco",
  autori = "Gruppo __ · classe __",
  messaggio = "",   -- scrivete qui, in una frase, cosa volete far capire a chi gioca
  tema = "",        -- "social", "chatbot", "male", "corpo", "relazioni" oppure ""
  presentazione = "",
  protagonista = "Ale",
  turni = 8,
  ordine = "in fila",

  grandezze = {
    { nome = "umore", livello = "vissuto", spiega = "come si sente", inizio = 0, min = -100, max = 100 },
  },

  azioni = {
    { nome = "Fai qualcosa", effetti = "umore + 10", dopo = "{nome} ci prova." },
    { nome = "Lascia stare", effetti = "", dopo = "Per oggi, niente." },
  },

  regole = {},

  eventi = {
    { fonte = "persona", chi = "Qualcuno",
      mostra = "Succede qualcosa. Cosa si vede?",
      nasconde = "",
      effetti = "umore - 10" },
  },

  opinioni = {},

  finali = {
    { titolo = "Finale", testo = "Com'è andata a {nome}? (umore finale: {umore})" },
  },
}
