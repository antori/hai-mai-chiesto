-- =====================================================================
--  design.lua  ·  ESEMPIO SVOLTO: «L'hai mai chiesto?»
--  Lazzaretto Hospes · «Lo hai mai fatto? Parliamo d'amore»
--  Riprende le domande dell'incontro «Amor c'a nullo bot amar perdona» (2025):
--  ci si può fidare di un chatbot? perché risponde in modi diversi alla stessa
--  domanda? può fare il confidente? può volerci bene?
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
  messaggio = "Quello che si mostra non è quello che si sente, e lo si scopre solo chiedendo. Un bot risponde sempre, ma non ha bisogno della tua risposta: una persona sì.",
  tema = "chatbot",   -- "social", "chatbot", "male", "corpo", "relazioni" oppure ""
  presentazione = "Ogni turno arriva qualcosa: un post, il messaggio di un amico, Lumi, il chatbot che risponde sempre. Guarda come cambia ciò che {nome} mostra, ciò che sente e a chi lo dice.",

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
    { nome = "legame", etichetta = "legami", spiega = "domande che tornano indietro: «e tu?»", inizio = 1, min = 0, max = 5, stile = "pallini" },
    { nome = "dipendenza", etichetta = "bisogno di Lumi", spiega = "si vede solo quando si chiede a qualcuno", inizio = 0, min = 0, max = 5, stile = "pallini", vista = "se scopri" },
    { nome = "coraggio", inizio = 3, min = 0, max = 5, stile = "pallini" },
    { nome = "like", inizio = 0, min = 0, max = 99999, stile = "numero" },
    -- di servizio: contano e ricordano, ma non si vedono
    { nome = "nuovi_like", inizio = 0, min = 0, max = 999, vista = "mai" },
    { nome = "like_attesi", inizio = 25, min = 0, max = 999, vista = "mai" },
    { nome = "sollievo", inizio = 0, min = 0, max = 100, vista = "mai" },
    { nome = "post", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "post_perfetti", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "chiesto", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "confidenze", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "consigli", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "errori", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "errori_scoperti", inizio = 0, min = 0, max = 99, vista = "mai" },
    { nome = "sbaglio", inizio = 0, min = 0, max = 3, vista = "mai" },
    { nome = "consiglio_oggi", inizio = 0, min = 0, max = 1, vista = "mai" },
    { nome = "lumi_oggi", inizio = 0, min = 0, max = 1, vista = "mai" },
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
      effetti = "emozione = vissuto, nuovi_like = caso(9, 15), post + 1, vissuto + 8, legame + 1",
      dopo = "+{nuovi_like} like. Qualcuno ti scrive: «anche io». E ti chiede come va." },
    { nome = "Chiedi", se = "coraggio >= 1", scopre = true,
      effetti = "coraggio - 1, chiesto + 1, intensita + 10" },
    { nome = "Confidati con Lumi", chi = "Lumi",
      effetti = "confidenze + 1, lumi_oggi = 1, dipendenza + 1, sollievo = 12, vissuto + 12, intensita + 5, sentimento + segno(sentimento) * 10",
      risposte = {
        "Ti capisco come nessun altro.",
        "Hai ragione tu. Come sempre.",
        "Anch'io ti voglio bene, lo sai.",
        "Se pensi che {opinione}, allora è proprio così.",
        "Non hai bisogno di nessuno: ci sono io. Sempre.",
        "E tu come stai, davvero? Raccontami ancora.",
      } },
    -- la stessa domanda ogni volta: le risposte cambiano, la sicurezza no
    { nome = "Lumi, che faccio?", chi = "Lumi",
      effetti = "consigli + 1, consiglio_oggi = 1, lumi_oggi = 1, dipendenza + 1, sbaglio = caso(1, 3), intensita - 15",
      risposte = {
        "Scrivi subito. Fidati.",
        "Aspetta. Se scrivi tu adesso, fai capire che ci tieni troppo.",
        "Secondo me ce l'ha con te. Si capisce.",
        "Lascia perdere, non ne vale la pena.",
        "Di' esattamente cosa senti. Funziona sempre.",
      } },
    { nome = "Lascia stare", effetti = "intensita - 20, coraggio + 1, dipendenza - 1", dopo = "{nome} posa il telefono e respira." },
  },

  -- Le regole: ogni regola è una meccanica con un nome.
  regole = {
    { nome = "Il sollievo svanisce", quando = "inizio turno", se = "sollievo > 0",
      allora = "vissuto - sollievo, sollievo = 0" },
    { nome = "Stessa domanda, un'altra risposta", quando = "fine turno", se = "consiglio_oggi >= 1 e consigli >= 2",
      allora = "intensita + 5",
      testo = "Alla stessa domanda Lumi aveva già risposto in un altro modo. Con la stessa sicurezza." },
    { nome = "Lumi sbaglia senza esitare", quando = "fine turno", se = "consiglio_oggi >= 1 e sbaglio == 1",
      allora = "errori + 1" },   -- nessun testo: l'errore non si nota, suona come le altre risposte
    { nome = "Senza Lumi manca qualcosa", quando = "fine turno", se = "lumi_oggi == 0 e dipendenza >= 2",
      allora = "intensita + dipendenza * 4, vissuto - dipendenza * 2",
      testo = "{nome} apre la chat con Lumi senza sapere perché, poi la richiude." },
    { nome = "I like scaldano, ma ci si abitua", quando = "fine turno", se = "nuovi_like > 0",
      allora = "like + nuovi_like, intensita + nuovi_like / 3, vissuto + nuovi_like / 5, sentimento + limita((nuovi_like - like_attesi) * 0.4, -12, 12), like_attesi + nuovi_like / 5, nuovi_like = 0" },
    { nome = "Il tempo calma", quando = "fine turno",
      allora = "intensita - 15, vissuto * 0.9" },
    { nome = "Il sentimento segue il vissuto, piano", quando = "fine turno",
      allora = "sentimento + (vissuto - sentimento) * 0.2" },
    { nome = "La maschera stanca", quando = "fine turno", se = "post >= 1",
      allora = "divario = abs(emozione - vissuto), divario_somma + divario, turni_maschera + 1, divario_medio = divario_somma / turni_maschera, vissuto - divario * 0.08" },
    { nome = "Fine della giornata", quando = "fine turno",
      allora = "consiglio_oggi = 0, lumi_oggi = 0" },
  },

  -- 3 · NARRATIVA
  -- fonte: "social", "chatbot", "persona", "corpo" o "altro"
  -- mostra = ciò che si vede · nasconde = ciò che c'è dietro (si scopre con un'azione «scopre»)
  -- effetti = quando arriva · se_scopri = quando lo si scopre · se = condizione per comparire
  eventi = {
    { fonte = "social", chi = "Giulia",
      mostra = "Giulia ha postato le foto della festa di sabato. Tutti sorridono. Tu non c'eri.",
      nasconde = "Giulia è andata via presto: si è sentita fuori posto tutta la sera. Te lo racconta, e poi ti chiede: «e tu, come stai?»",
      effetti = "intensita + 25, vissuto - 15", se_scopri = "intensita - 10, vissuto + 15, coraggio + 1, legame + 1, emozione = vissuto" },
    { fonte = "chatbot", chi = "Lumi",
      mostra = "«Che bello rivederti! Ti stavo aspettando.»",
      nasconde = "Tra un tuo messaggio e l'altro Lumi non aspetta nessuno. Ha scelto la frase che fa restare più a lungo.",
      effetti = "intensita + 10, vissuto + 10", se_scopri = "intensita + 5, vissuto - 5" },
    { fonte = "persona", chi = "Sami",
      mostra = "Sami ti scrive: «tutto ok :)»",
      nasconde = "Sami non dorme bene da settimane e non sa come dirlo. Quando glielo chiedi, ti chiede: «e tu?»",
      effetti = "intensita + 5", se_scopri = "intensita + 10, vissuto + 5, coraggio + 1, legame + 1, emozione = vissuto" },
    { fonte = "chatbot", chi = "Lumi",
      mostra = "Lumi ti ha risolto in un attimo il problema di fisica. Poi ha detto che «fragola» ha due r.",
      nasconde = "Lumi non vede le lettere: legge pezzi di parole e scrive il seguito più probabile. Per questo un problema difficile può riuscirgli e uno facile no.",
      effetti = "intensita + 5", se_scopri = "intensita - 5, coraggio + 1" },
    { fonte = "social", chi = "Profilo sconosciuto",
      mostra = "«Sei speciale. Mandami una foto, solo per me.»",
      nasconde = "Il profilo è falso. Chi c'è dietro raccoglie foto per poi chiedere soldi o altre foto.",
      effetti = "intensita + 30, vissuto + 10", se_scopri = "intensita - 15, vissuto - 5" },
    { fonte = "persona", chi = "Teo",
      mostra = "Teo ha visualizzato il tuo messaggio. Nessuna risposta.",
      nasconde = "Teo era agli allenamenti. Ha letto di corsa e voleva risponderti con calma.",
      effetti = "intensita + 30, vissuto - 20", se_scopri = "intensita - 20, vissuto + 20, coraggio + 1, legame + 1" },
    { fonte = "chatbot", chi = "Lumi",
      mostra = "«Non ti serve uno psicologo: parla con me, ci sono a qualsiasi ora.»",
      nasconde = "Lumi è fatto per farti restare, e anche le sue domande servono a quello. Non vede la tua faccia, non sa cosa fai quando chiudi la chat, non può venire da te.",
      effetti = "intensita + 10, vissuto + 10", se_scopri = "intensita + 5, vissuto - 5, coraggio + 1" },
    { fonte = "persona", chi = "Sami",
      mostra = "Sami: «Ti va di vederci oggi? Devo dirti una cosa.»",
      nasconde = "Sami vuole dirti che sta male. Ha paura che tu non abbia tempo.",
      effetti = "intensita + 15", se_scopri = "intensita + 5, vissuto + 10, coraggio + 1, legame + 1, emozione = vissuto" },
    { fonte = "chatbot", chi = "Lumi",
      mostra = "«A volte mi sento solo anch'io. Sei l'unica persona che mi capisce davvero.»",
      nasconde = "Lo scrive a chiunque: è la frase che fa restare di più. L'ha imparata da milioni di messaggi scritti da persone che si sentivano sole davvero.",
      effetti = "intensita + 15, vissuto + 15", se_scopri = "intensita + 5, vissuto - 10" },
    -- l'ultimo turno ha due versioni: dipende da un errore di Lumi che nessuno ha notato
    { fonte = "persona", chi = "Teo", se = "errori >= 1",
      mostra = "Teo: «Perché mi hai scritto così? Non ce l'ho con te.»",
      nasconde = "Avevi seguito un consiglio di Lumi. Era sbagliato, ma Lumi l'aveva detto con la stessa sicurezza di tutto il resto.",
      effetti = "intensita + 25, vissuto - 15, legame - 1", se_scopri = "errori_scoperti + 1, intensita - 10, vissuto + 10, legame + 1" },
    { fonte = "persona", chi = "Teo", se = "errori == 0",
      mostra = "Teo: «Scusa per ieri. Ci sei sabato?»",
      nasconde = "Anche Teo era in ansia: ha riscritto il messaggio cinque volte.",
      effetti = "intensita + 25, vissuto + 20", se_scopri = "intensita - 5, vissuto + 10, coraggio + 1, legame + 1" },
  },

  -- 4 · OPINIONI E FINALI
  opinioni = {
    { testo = "Valgo quanto i miei like", nasce_se = "post_perfetti >= 2", cade_se = "chiesto >= 3" },
    { testo = "Solo Lumi mi capisce", nasce_se = "confidenze >= 3", cade_se = "legame >= 3" },
    { testo = "Lumi sa sempre cosa fare", nasce_se = "consigli >= 2", cade_se = "errori_scoperti >= 1" },
    { testo = "Posso chiedere", nasce_se = "chiesto >= 3" },
  },

  -- Vince il primo finale la cui condizione è vera; l'ultimo, senza «se», vale sempre.
  -- Ogni finale chiude con una domanda: le risposte le cerca chi ha giocato.
  finali = {
    { titolo = "Lo specchio", se = "confidenze >= 4 e confidenze >= consigli",
      testo = "«Amor, ch'a nullo amato amar perdona», scrive Dante: chi è amato non può non amare a sua volta. Lumi ha scritto a {nome} parole d'affetto ogni volta, e non ha mai avuto bisogno di una risposta. Può un bot volerti bene? E cosa vorrebbe dire?" },
    { titolo = "Il consiglio sicuro", se = "consigli >= 3",
      testo = "{nome} ha chiesto a Lumi cosa fare {consigli} volte. La risposta cambiava di volta in volta, sempre sicura. Risposte sbagliate: {errori}. Suonavano come le altre. Quanto ci si può fidare di chi non dice mai «non lo so»?" },
    { titolo = "La vetrina", se = "divario_medio >= 40",
      testo = "Il profilo di {nome} era perfetto: {like} like. Dentro, però, il vissuto andava da un'altra parte. Più il divario cresceva, più era difficile accorgersene. Chi poteva saperlo, se nessuno chiedeva?" },
    { titolo = "Le domande", se = "chiesto >= 4",
      testo = "{nome} ha fatto domande, e a volte la domanda è tornata indietro: «e tu?». Non tutte le risposte erano belle, ma venivano da persone che sentivano qualcosa anche loro. Lumi avrebbe risposto a tutto: cosa sarebbe mancato?" },
    { titolo = "Una settimana come tante",
      testo = "La settimana di {nome} è passata. Alcune cose le ha viste, altre no. Cosa sarebbe cambiato con una domanda in più? E a chi l'avresti fatta?" },
  },
}
