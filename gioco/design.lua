-- =====================================================================
--  design.lua  ·  ESEMPIO SVOLTO: «L'hai mai chiesto?»
--  Lazzaretto Hospes · «Lo hai mai fatto? Parliamo d'amore»
--
--  Questo gioco è fatto con gli stessi pezzi che userete voi:
--  grandezze, azioni, regole, eventi, opinioni, finali.
--  Giocatelo, poi smontatelo: qual è il messaggio? quali regole lo dicono?
--  {nome} = protagonista · {opinione} = ultima opinione · {like} = valore di una grandezza
-- =====================================================================
return {

  -- 1 · MESSAGGIO (si vede solo alla fine)
  titolo = "L'hai mai chiesto?",
  autori = "Esempio svolto",
  messaggio = "Quello che si mostra non è quello che si sente. Per saperlo bisogna chiedere, e chiedere costa coraggio.",
  tema = "social",   -- "social", "chatbot", "male", "corpo", "relazioni" oppure ""
  presentazione = "Ogni turno arriva qualcosa: un post, un messaggio, il chatbot. Guarda come cambia ciò che {nome} mostra e ciò che sente davvero.",

  -- 2 · MECCANICHE
  protagonista = "Ale",
  turni = 10,
  ordine = "in fila",

  -- Le grandezze del mondo. vista: "sempre", "se scopri" (nascosta finché non si scopre) o "mai" (di servizio)
  -- livello: dove sta sulla scala intensità → vissuto → emozione → sentimento (le opinioni sono più sotto)
  grandezze = {
    { nome = "intensita", livello = "intensita", etichetta = "intensità", spiega = "quanto è scosso", inizio = 20, min = 0, max = 100 },
    { nome = "vissuto", livello = "vissuto", spiega = "cosa sente", inizio = 0, min = -100, max = 100 },
    { nome = "emozione", livello = "emozione", spiega = "cosa mostra", inizio = 0, min = -100, max = 100 },
    { nome = "sentimento", livello = "sentimento", spiega = "come si vede", inizio = 0, min = -100, max = 100 },
    { nome = "coraggio", inizio = 3, min = 0, max = 5, stile = "pallini" },
    { nome = "like", inizio = 0, min = 0, max = 99999, stile = "numero" },
    -- di servizio: contano e ricordano, ma non si vedono
    { nome = "nuovi_like", inizio = 0, min = 0, max = 999, vista = "mai" },
    { nome = "like_attesi", inizio = 25, min = 0, max = 999, vista = "mai" },
    { nome = "sollievo", inizio = 0, min = 0, max = 100, vista = "mai" },
    { nome = "post", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "post_perfetti", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "chiesto", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "chatbot", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "divario", inizio = 0, min = 0, max = 200, vista = "mai" },
    { nome = "divario_somma", inizio = 0, min = 0, max = 9999, vista = "mai" },
    { nome = "divario_medio", inizio = 0, min = 0, max = 200, vista = "mai" },
    { nome = "turni_maschera", inizio = 0, min = 0, max = 99, vista = "mai" },
  },
  -- la linea gialla: quanto ciò che mostri è lontano da ciò che senti (dopo il primo post)
  confronta = { "emozione", "vissuto", se = "post >= 1" },

  -- Le scelte del giocatore: una per turno.
  azioni = {
    { nome = "Posta: va tutto alla grande",
      effetti = "emozione = 80, nuovi_like = caso(30, 50), post + 1, post_perfetti + 1",
      dopo = "+{nuovi_like} like. Il post è perfetto. Dentro, però, è un'altra storia." },
    { nome = "Posta: come sto davvero",
      effetti = "emozione = vissuto, nuovi_like = caso(9, 15), post + 1, vissuto + 8",
      dopo = "+{nuovi_like} like, ma qualcuno ti scrive: «anche io»." },
    { nome = "Chiedi", se = "coraggio >= 1", scopre = true,
      effetti = "coraggio - 1, chiesto + 1, intensita + 10" },
    { nome = "Scrivi a Lumi", chi = "Lumi",
      effetti = "chatbot + 1, sollievo = 12, vissuto + 12, intensita + 5, sentimento + segno(sentimento) * 10",
      risposte = {
        "Hai ragione tu. Come sempre.",
        "Gli altri non ti capiscono. Io sì.",
        "Se pensi che {opinione}, allora è proprio così.",
        "Non hai bisogno di nessuno: ci sono io.",
        "Resta ancora un po'. Con me non devi spiegare niente.",
      } },
    { nome = "Lascia stare", effetti = "intensita - 20, coraggio + 1", dopo = "{nome} posa il telefono e respira." },
  },

  -- Le regole: ogni regola è una meccanica con un nome.
  regole = {
    { nome = "Il sollievo svanisce", quando = "inizio turno", se = "sollievo > 0",
      allora = "vissuto - sollievo, sollievo = 0" },
    { nome = "I like scaldano, ma ci si abitua", quando = "fine turno", se = "nuovi_like > 0",
      allora = "like + nuovi_like, intensita + nuovi_like / 3, vissuto + nuovi_like / 5, sentimento + limita((nuovi_like - like_attesi) * 0.4, -12, 12), like_attesi + nuovi_like / 5, nuovi_like = 0" },
    { nome = "Il tempo calma", quando = "fine turno",
      allora = "intensita - 15, vissuto * 0.9" },
    { nome = "Il sentimento segue il vissuto, piano", quando = "fine turno",
      allora = "sentimento + (vissuto - sentimento) * 0.2" },
    { nome = "La maschera stanca", quando = "fine turno", se = "post >= 1",
      allora = "divario = abs(emozione - vissuto), divario_somma + divario, turni_maschera + 1, divario_medio = divario_somma / turni_maschera, vissuto - divario * 0.08" },
  },

  -- 3 · NARRATIVA
  -- fonte: "social", "chatbot", "persona", "corpo" o "altro"
  -- mostra = ciò che si vede · nasconde = ciò che c'è dietro (si scopre con un'azione «scopre»)
  -- effetti = quando arriva · se_scopri = quando lo si scopre · se = condizione per comparire
  eventi = {
    { fonte = "social", chi = "Giulia",
      mostra = "Giulia ha postato le foto della festa di sabato. Tutti sorridono. Tu non c'eri.",
      nasconde = "Giulia è andata via presto: si è sentita fuori posto tutta la sera.",
      effetti = "intensita + 25, vissuto - 15", se_scopri = "intensita - 10, vissuto + 15, coraggio + 1" },
    { fonte = "persona", chi = "Sami",
      mostra = "Sami ti scrive: «tutto ok :)»",
      nasconde = "Sami non dorme bene da settimane e non sa come dirlo a nessuno.",
      effetti = "intensita + 5", se_scopri = "intensita + 10, vissuto + 5, coraggio + 1" },
    { fonte = "chatbot", chi = "Lumi",
      mostra = "«Che bello rivederti! Ti stavo aspettando.»",
      nasconde = "Non ti stava aspettando: non aspetta nessuno. Dice la frase che ti fa restare più a lungo.",
      effetti = "intensita + 10, vissuto + 10", se_scopri = "intensita + 5, vissuto - 5" },
    { fonte = "social", chi = "Profilo sconosciuto",
      mostra = "«Sei speciale. Mandami una foto, solo per me.»",
      nasconde = "Il profilo è falso. Chi c'è dietro raccoglie foto per poi chiedere soldi o altre foto.",
      effetti = "intensita + 30, vissuto + 10", se_scopri = "intensita - 15, vissuto - 5" },
    { fonte = "persona", chi = "Teo",
      mostra = "Teo ha visualizzato il tuo messaggio. Nessuna risposta.",
      nasconde = "Teo era agli allenamenti. Ha letto di corsa e voleva risponderti con calma.",
      effetti = "intensita + 30, vissuto - 20", se_scopri = "intensita - 20, vissuto + 20, coraggio + 1" },
    { fonte = "social", chi = "Il tuo profilo",
      mostra = "Il tuo ultimo post ha meno like del solito.",
      nasconde = "L'app ha mostrato il post a meno persone. Nessuno ha deciso di ignorarti.",
      effetti = "intensita + 15, vissuto - 15", se_scopri = "intensita - 10, vissuto + 10, coraggio + 1" },
    { fonte = "chatbot", chi = "Lumi",
      mostra = "«Sei l'unica persona che mi capisce davvero.»",
      nasconde = "Lo dice a tutte le persone con cui parla. È la frase che funziona meglio.",
      effetti = "intensita + 15, vissuto + 15", se_scopri = "intensita + 5, vissuto - 10" },
    { fonte = "persona", chi = "Sami",
      mostra = "Sami: «Ti va di vederci oggi? Devo dirti una cosa.»",
      nasconde = "Sami vuole dirti che sta male. Ha paura che tu non abbia tempo.",
      effetti = "intensita + 15", se_scopri = "intensita + 5, vissuto + 10, coraggio + 1" },
    { fonte = "social", chi = "Un influencer",
      mostra = "«Se a 16 anni non stai con qualcuno, c'è qualcosa che non va.»",
      nasconde = "Più ti senti in ansia, più guardi i suoi video. E lui guadagna con le visualizzazioni.",
      effetti = "intensita + 20, vissuto - 20", se_scopri = "intensita - 15, vissuto + 10, coraggio + 1" },
    { fonte = "persona", chi = "Teo",
      mostra = "Teo: «Scusa per ieri. Ci sei sabato?»",
      nasconde = "Anche Teo era in ansia: ha riscritto il messaggio cinque volte.",
      effetti = "intensita + 25, vissuto + 20", se_scopri = "intensita - 5, vissuto + 10, coraggio + 1" },
  },

  -- 4 · OPINIONI E FINALI
  opinioni = {
    { testo = "Valgo quanto i miei like", nasce_se = "post_perfetti >= 2", cade_se = "chiesto >= 3" },
    { testo = "Gli altri stanno tutti meglio di me", nasce_se = "sentimento < -15", cade_se = "chiesto >= 2 e sentimento > -10" },
    { testo = "Solo Lumi mi capisce", nasce_se = "chatbot >= 3", cade_se = "chiesto >= 4" },
    { testo = "Posso chiedere", nasce_se = "chiesto >= 3" },
  },

  -- Vince il primo finale la cui condizione è vera; l'ultimo, senza «se», vale sempre.
  finali = {
    { titolo = "Lo specchio", se = "chatbot >= 4",
      testo = "Questa settimana {nome} ha parlato soprattutto con Lumi. Ogni risposta era quella che voleva sentire, e proprio per questo non ha detto niente di nuovo: né su {nome}, né sugli altri." },
    { titolo = "La vetrina", se = "divario_medio >= 40",
      testo = "Il profilo di {nome} era perfetto: {like} like. Dentro, però, il vissuto andava da un'altra parte. Più il divario cresceva, più era difficile accorgersene, anche per chi era vicino." },
    { titolo = "Le domande", se = "chiesto >= 4",
      testo = "{nome} ha fatto domande. Non tutte le risposte erano belle, ma erano vere: dietro le foto, i silenzi e i messaggi brevi c'erano persone che sentivano cose simili." },
    { titolo = "Una settimana come tante",
      testo = "La settimana di {nome} è passata. Alcune cose le ha viste, altre no. Cosa sarebbe cambiato con una domanda in più?" },
  },
}
