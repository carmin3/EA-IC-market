//+------------------------------------------------------------------+
//|                                            Comparatore_v2.14.mq5 |
//|                                                         Carmin3  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Carmin3"
#property link      "https://www.mql5.com"
#property version   "2.14"
#property description "EA con sistema Citadel + initial_fluctuation_percent"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| PARAMETRI INPUT ORGANIZZATI                                     |
//+------------------------------------------------------------------+

input group "=== Parametri Analisi Correlazioni ==="
input int SMAperiod = 11;                      // Periodo della SMA - già ottimizzato
input int TimeBack = 40;                       // Numero di minuti da recuperare per analisi - tra 40 e 41 oppure tra 56 e 62
input double soglia_aderenza = 75.0;           // Soglia minima aderenza per considerare correlazione valida
input int sfasamento_max = 25;                 // Massimo sfasamento temporale da analizzare (minuti) - tra 24 e 27 oppure tra 41 e 47

input group "=== Parametri Trading ==="
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M1;   // Timeframe di trading
input int indici_su_cui_tradeare = 5;          // Numero di migliori correlazioni su cui operare
//input double lot_size = 0.10;                  // Dimensione del lotto per trade
input double check_cycle = 1;                  // Tempo del ciclo di controllo entrata posizione (minuti)
input double available_liquidity_percent = 0.05; // Percentuale del capitale disponibile da utilizzare

input group "=== Parametri Citadel Exit Strategy ==="
input int ema_fast_period = 1;                 // Periodo EMA veloce
input int ema_medium_period = 18;              // Periodo EMA media
input int trend_confirmation_bars = 9;         // Barre consecutive per conferma trend (5 secondi per barra)
input double min_price_change_points = 1.0;    // Variazione minima prezzo per ricalcolo (in punti)
input int check_frequency_ticks = 2;           // Frequenza controllo ogni N tick
input double initial_fluctuation_percent = 0.1; // Percentuale range fluttuazione iniziale
input int range_exit_confirmation_ticks = 3;    // Tick consecutivi per conferma uscita range
input double breakeven_sl_margin_percent = 0.05;// Margine percentuale sotto entry per SL

input group "=== Parametri Take Profit Gerarchico ==="
input double min_profit_threshold_usd = 5.0;   // Soglia minima profitto USD per attivazione Citadel
input double safety_take_profit_percent = 2.5; // Take Profit fisso di sicurezza (safety net)
input double citadel_profit_protection = 1.0;  // Margine di protezione profitto per Citadel

input group "=== Parametri Stop Loss ==="
input double initial_stop_percentage = 30.0;   // Percentuale iniziale stop loss

input group "=== Parametri Alert ==="
input double significant_profit_threshold = 100.0; // Soglia per alert di profitto significativo

//+------------------------------------------------------------------+
//| COSTANTI GLOBALI                                               |
//+------------------------------------------------------------------+
#define MAX_LAG_TOLERANCE_SECONDS 30           // Tolleranza massima per matching temporale
#define MIN_OHLC_VALIDATION_THRESHOLD 0.10     // Soglia minima per validazione dati OHLC (10%)
#define CITADEL_BAR_DURATION_SECONDS 5         // Durata barra in secondi per strategia Citadel

//+------------------------------------------------------------------+
//| ARRAY DEI SIMBOLI                                               |
//+------------------------------------------------------------------+
string SymbolNames[] = {"AAPL.NAS", "ABNB.NAS", "ADBE.NAS", "ADSK.NAS", "AEP.NAS", "AFRM.NAS", "ALGN.NAS", "AMAT.NAS", "AMD.NAS", "AMGN.NAS", "AMZN.NAS", "AZN.NAS", "BIDU.NAS", "BILI.NAS", "BIIB.NAS", "BKNG.NAS", "BLNK.NAS", "BNGO.NAS", "BNTX.NAS", "BYND.NAS", "BZUN.NAS", "CDW.NAS", "CDNS.NAS", "CELH.NAS", "CHKP.NAS", "CHTR.NAS", "CMCSA.NAS", "COIN.NAS", "COST.NAS", "CPRT.NAS", "CROX.NAS", "CRSR.NAS", "CRWD.NAS", "CSX.NAS", "CTAS.NAS", "CTSH.NAS", "CYBR.NAS", "DBX.NAS", "DDOG.NAS", "DKNG.NAS", "DLTR.NAS", "DOCU.NAS", "DXCM.NAS", "EA.NAS", "EBAY.NAS", "EQIX.NAS", "ETSY.NAS", "EXAS.NAS", "EXPE.NAS", "FANG.NAS", "FAST.NAS", "FCEL.NAS", "FISV.NAS", "FITB.NAS", "FLEX.NAS", "FOXA.NAS", "FTNT.NAS", "GILD.NAS", "GOOG.NAS", "GRAB.NAS", "HBAN.NAS", "HOLX.NAS", "HOOD.NAS", "IBB.NAS", "IBKR.NAS", "IDXX.NAS", "ILMN.NAS", "INCY.NAS", "INTC.NAS", "INTU.NAS", "ISRG.NAS", "JBLU.NAS", "KHC.NAS", "KLAC.NAS", "LAMR.NAS", "LAZR.NAS", "LPLA.NAS", "LRCX.NAS", "LULU.NAS", "LYFT.NAS", "MAR.NAS", "MARA.NAS", "MCHP.NAS", "MELI.NAS", "MNST.NAS", "MRNA.NAS", "MRVL.NAS", "MSFT.NAS", "MSTR.NAS", "MTCH.NAS", "MU.NAS", "NFLX.NAS", "NTNX.NAS", "NVAX.NAS", "NVDA.NAS", "NXPI.NAS", "OCGN.NAS", "ODFL.NAS", "OKTA.NAS", "ON.NAS", "OPEN.NAS", "ORLY.NAS", "PAYX.NAS", "PCAR.NAS", "PDD.NAS", "PENN.NAS", "PEP.NAS", "PLTR.NAS", "PLUG.NAS", "PODD.NAS", "QQQ.NAS", "QCOM.NAS", "QRVO.NAS", "REGN.NAS", "RIVN.NAS", "RKLB.NAS", "ROKU.NAS", "ROST.NAS", "SBAC.NAS", "SBUX.NAS", "SFIX.NAS", "SHY.NAS", "SIRI.NAS", "SMH.NAS", "SNDL.NAS", "SNPS.NAS", "SOFI.NAS", "SOXX.NAS", "STNE.NAS", "SWKS.NAS", "TEAM.NAS", "TLRY.NAS", "TLT.NAS", "TMUS.NAS", "TRIP.NAS", "TROW.NAS", "TSLA.NAS", "TTD.NAS", "TTWO.NAS", "TXN.NAS", "UAL.NAS", "UPST.NAS", "UPWK.NAS", "VCYT.NAS", "VEON.NAS", "VRSN.NAS", "VRTX.NAS", "WB.NAS", "WBA.NAS", "WDAY.NAS", "WIX.NAS", "WISH.NAS", "WYNN.NAS", "XEL.NAS", "XRAY.NAS", "Z.NAS", "ZG.NAS", "ZI.NAS", "ZM.NAS", "ZS.NAS", "AUS200", "DE40", "F40", "JP225", "STOXX50", "UK100", "US30", "US500", "USTEC", "CA60", "CHINA50", "CHINAH", "ES35", "HK50", "IT40", "MidDE50", "NETH25", "NOR25", "SA40", "SE30", "SWI20", "TecDE30", "US2000", "XBRUSD", "XTIUSD", "XNGUSD", "EURUSD", "GBPUSD", "USDCAD", "USDCHF", "USDJPY"};

//+------------------------------------------------------------------+
//| STRUTTURE DATI                                                  |
//+------------------------------------------------------------------+

struct AderenzaResult {
    string master_symbol;
    string slave_symbol;
    int sfasamento;
    double aderenza;
    double scarto_medio;
};

struct CitadelPositionData {
    ulong ticket;
    string symbol;
    double entry_price;
    double ema_fast_current;
    double ema_fast_previous;
    double ema_medium_current;
    double ema_medium_previous;
    int downtrend_bars_count;
    datetime last_bar_time;
    double last_price_check;
    double upper_range_limit;         // Limite superiore range iniziale
    double lower_range_limit;         // Limite inferiore range iniziale
    int ticks_above_range;           // Contatore tick sopra range
    int ticks_below_range;           // Contatore tick sotto range
    bool initial_range_active;        // Flag range iniziale attivo
    bool uptrend_confirmed;          // Flag uptrend confermato
    datetime range_exit_time;        // Timestamp uscita dal range
};

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI                                               |
//+------------------------------------------------------------------+

matrix results;
int symbolCount;
datetime dateTimeArray[];
AderenzaResult aderenceResults[];

datetime lastExecutionTime = 0;
datetime next_checking_time = 0;
datetime lastTradeCheckTime = 0;
datetime currentTime;

double currentPrice;

int g_delayTimes[];
string g_masterSymbols[];
string g_slaveSymbols[];
bool g_orderStates[];

CTrade trade_Buy;
CPositionInfo position;

int tickCounter = 0;
CitadelPositionData managedPositions[];

//+------------------------------------------------------------------+
//| CLASSE CITADEL EXIT MANAGER - SISTEMA GERARCHICO               |
//+------------------------------------------------------------------+
class CCitadelExitManager {
public:
    // Aggiunge nuova posizione al sistema di gestione Citadel
    static bool AddPosition(ulong ticket, string symbol, double entry_price) {
        CitadelPositionData newPos;
        
        // Inizializzazione campi esistenti
        newPos.ticket = ticket;
        newPos.symbol = symbol;
        newPos.entry_price = entry_price;
        newPos.ema_fast_current = entry_price;
        newPos.ema_fast_previous = entry_price;
        newPos.ema_medium_current = entry_price;
        newPos.ema_medium_previous = entry_price;
        newPos.downtrend_bars_count = 0;
        newPos.last_bar_time = TimeCurrent();
        newPos.last_price_check = entry_price;
        
        // Inizializzazione nuovi campi per range iniziale
        newPos.upper_range_limit = entry_price * (1 + initial_fluctuation_percent/100);
        newPos.lower_range_limit = entry_price * (1 - initial_fluctuation_percent/100);
        newPos.ticks_above_range = 0;
        newPos.ticks_below_range = 0;
        newPos.initial_range_active = true;
        newPos.uptrend_confirmed = false;
        newPos.range_exit_time = 0;
        
        int size = ArraySize(managedPositions);
        ArrayResize(managedPositions, size + 1);
        int newSize = ArraySize(managedPositions);
        
        if(size >= 0 && size < newSize) {
            managedPositions[size] = newPos;
            Print("[CITADEL] Posizione aggiunta al sistema gerarchico - Ticket: ", ticket, 
                  " | Symbol: ", symbol, 
                  " | Entry Price: ", DoubleToString(entry_price, 5),
                  " | Range: ", DoubleToString(newPos.lower_range_limit, 5),
                  " - ", DoubleToString(newPos.upper_range_limit, 5));
            return true;
        }
        
        Print("[ERROR] Impossibile aggiungere posizione al Citadel Manager - Ticket: ", ticket, " | Symbol: ", symbol);
        return false;
    }
    
    // Rimuove posizione dal sistema di gestione
    static bool RemovePosition(ulong ticket) {
        int size = ArraySize(managedPositions);
        
        for(int i = 0; i < size; i++) {
            if(i >= 0 && i < ArraySize(managedPositions) && managedPositions[i].ticket == ticket) {
                if(i < size - 1) {
                    int lastIndex = size - 1;
                    if(lastIndex >= 0 && lastIndex < ArraySize(managedPositions)) {
                        managedPositions[i] = managedPositions[lastIndex];
                    }
                }
                
                ArrayResize(managedPositions, size - 1);
                Print("[CITADEL] Posizione rimossa dal sistema gerarchico - Ticket: ", ticket);
                return true;
            }
        }
        
        Print("[ERROR] Impossibile rimuovere posizione dal Citadel Manager - Ticket: ", ticket, " non trovato");
        return false;
    }
    
    // Aggiorna tutte le posizioni gestite dal sistema Citadel
    static void UpdateAllPositions() {
        int initialSize = ArraySize(managedPositions);
        
        if(initialSize == 0) {
            return;
        }
        
        datetime current_time = TimeCurrent();
        
        // Crea copia temporanea per evitare modifiche durante iterazione
        CitadelPositionData tempPositions[];
        ArrayResize(tempPositions, initialSize);
        
        for(int i = 0; i < initialSize; i++) {
            if(i >= 0 && i < ArraySize(managedPositions)) {
                tempPositions[i] = managedPositions[i];
            }
        }
        
        // Processa ogni posizione
        for(int i = 0; i < initialSize; i++) {
            ulong ticket = tempPositions[i].ticket;
            
            // Verifica se posizione esiste ancora
            if(!PositionSelectByTicket(ticket)) {
                RemovePosition(ticket);
                continue;
            }
            
            int currentIndex = FindPositionIndex(ticket);
            if(currentIndex == -1) {
                continue;
            }
            
            string symbol = managedPositions[currentIndex].symbol;
            double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
            
            if(current_price == 0) {
                Print("[ERROR] Impossibile ottenere prezzo BID per ", symbol, " - Ticket: ", ticket);
                continue;
            }
            
            double position_profit = PositionGetDouble(POSITION_PROFIT);
            
            // NUOVA LOGICA: Gestione range iniziale
            if(managedPositions[currentIndex].initial_range_active) {
                // Controllo se il prezzo è fuori dal range
                if(current_price > managedPositions[currentIndex].upper_range_limit) {
                    managedPositions[currentIndex].ticks_above_range++;
                    managedPositions[currentIndex].ticks_below_range = 0;
                    
                    // Verifica conferma uscita uptrend
                    if(managedPositions[currentIndex].ticks_above_range >= range_exit_confirmation_ticks) {
                        // Conferma uptrend
                        managedPositions[currentIndex].initial_range_active = false;
                        managedPositions[currentIndex].uptrend_confirmed = true;
                        managedPositions[currentIndex].range_exit_time = current_time;
                        
                        // Setta stop loss appena sotto il prezzo di entrata
                        double new_sl = managedPositions[currentIndex].entry_price * (1 - breakeven_sl_margin_percent/100);
                        CTrade trade;
                        if(trade.PositionModify(ticket, new_sl, 0)) {  // Manteniamo il TP esistente
                            Print("[CITADEL] Uptrend confermato - Nuovo SL: ", DoubleToString(new_sl, 5), 
                                  " | Ticket: ", ticket, " | Symbol: ", symbol);
                        }
                    }
                }
                else if(current_price < managedPositions[currentIndex].lower_range_limit) {
                    managedPositions[currentIndex].ticks_below_range++;
                    managedPositions[currentIndex].ticks_above_range = 0;
                    
                    // Per ora non gestiamo il downtrend confermato
                    // Lo implementeremo nella prossima fase
                }
                else {
                    // Prezzo dentro il range, resetta contatori
                    managedPositions[currentIndex].ticks_above_range = 0;
                    managedPositions[currentIndex].ticks_below_range = 0;
                }
            }
            
            // LOGICA ESISTENTE: Applica Citadel solo se uptrend confermato
            if(!managedPositions[currentIndex].initial_range_active && 
               managedPositions[currentIndex].uptrend_confirmed) {
                
                // Aggiorna EMA se variazione prezzo significativa
                double price_change = MathAbs(current_price - managedPositions[currentIndex].last_price_check);
                double min_change = min_price_change_points * SymbolInfoDouble(symbol, SYMBOL_POINT);
                
                if(price_change >= min_change) {
                    UpdateEMAForPosition(currentIndex, current_price);
                    
                    int newIndex = FindPositionIndex(ticket);
                    if(newIndex != -1) {
                        managedPositions[newIndex].last_price_check = current_price;
                    }
                }
                
                // Controlla trend e exit se tempo barra scaduto
                if(current_time - managedPositions[currentIndex].last_bar_time >= CITADEL_BAR_DURATION_SECONDS) {
                    CheckTrendAndExit(currentIndex, position_profit);
                    
                    int newIndex = FindPositionIndex(ticket);
                    if(newIndex != -1) {
                        managedPositions[newIndex].last_bar_time = current_time;
                    }
                }
            }
        }
    }
    
    // Trova indice di posizione nell'array managedPositions
    static int FindPositionIndex(ulong ticket) {
        int size = ArraySize(managedPositions);
        for(int i = 0; i < size; i++) {
            if(i >= 0 && i < ArraySize(managedPositions) && managedPositions[i].ticket == ticket) {
                return i;
            }
        }
        return -1;
    }
    
    // Aggiorna valori EMA per una specifica posizione
    static void UpdateEMAForPosition(int pos_index, double current_price) {
        if(pos_index < 0 || pos_index >= ArraySize(managedPositions)) {
            Print("[ERROR] Indice posizione non valido per aggiornamento EMA: ", pos_index, " | Array size: ", ArraySize(managedPositions));
            return;
        }
        
        // Salva valori precedenti
        managedPositions[pos_index].ema_fast_previous = managedPositions[pos_index].ema_fast_current;
        managedPositions[pos_index].ema_medium_previous = managedPositions[pos_index].ema_medium_current;
        
        // Calcola nuovi valori EMA usando smoothing factor
        double alpha_fast = 2.0 / (ema_fast_period + 1);
        double alpha_medium = 2.0 / (ema_medium_period + 1);
        
        managedPositions[pos_index].ema_fast_current = (current_price * alpha_fast) + 
                                                      (managedPositions[pos_index].ema_fast_current * (1 - alpha_fast));
        managedPositions[pos_index].ema_medium_current = (current_price * alpha_medium) + 
                                                        (managedPositions[pos_index].ema_medium_current * (1 - alpha_medium));
    }
    
    // Analizza trend e decide se uscire dalla posizione - Sistema Gerarchico
    static void CheckTrendAndExit(int pos_index, double current_profit) {
        if(pos_index < 0 || pos_index >= ArraySize(managedPositions)) {
            Print("[ERROR] Indice posizione non valido per controllo trend: ", pos_index, " | Array size: ", ArraySize(managedPositions));
            return;
        }
        
        // Verifica soglia minima profitto per attivazione Citadel (sistema gerarchico)
        if(current_profit < min_profit_threshold_usd) {
            return; // Citadel non attivo sotto soglia minima
        }
        
        int downtrend_conditions = 0;
        
        // Condizione 1: EMA veloce in discesa
        if(managedPositions[pos_index].ema_fast_current < managedPositions[pos_index].ema_fast_previous) {
            downtrend_conditions++;
        }
        
        // Condizione 2: EMA media in discesa
        if(managedPositions[pos_index].ema_medium_current < managedPositions[pos_index].ema_medium_previous) {
            downtrend_conditions++;
        }
        
        // Condizione 3: Prezzo sotto EMA veloce
        double current_price = SymbolInfoDouble(managedPositions[pos_index].symbol, SYMBOL_BID);
        if(current_price < managedPositions[pos_index].ema_fast_current) {
            downtrend_conditions++;
        }
        
        // Conta barre consecutive di downtrend
        if(downtrend_conditions >= 2) {
            managedPositions[pos_index].downtrend_bars_count++;
        } else {
            managedPositions[pos_index].downtrend_bars_count = 0;
        }
        
        // Esegui exit se trend confermato
        if(managedPositions[pos_index].downtrend_bars_count >= trend_confirmation_bars) {
            ulong ticket = managedPositions[pos_index].ticket;
            
            // Calcola profitto protetto (sistema gerarchico)
            double protected_profit = current_profit - citadel_profit_protection;
            
            if(protected_profit > 0) {
                ExecuteCitadelExit(ticket, managedPositions[pos_index].symbol, 
                                 "Sistema Gerarchico - Downtrend confermato");
            }
        }
    }
    
    // Esegue chiusura posizione con priorità Citadel (sistema gerarchico)
    static void ExecuteCitadelExit(ulong ticket, string symbol, string reason) {
        if(!PositionSelectByTicket(ticket)) {
            Print("[ERROR] Posizione non trovata per ExecuteCitadelExit - Ticket: ", ticket);
            return;
        }
        
        double final_profit = PositionGetDouble(POSITION_PROFIT);
        
        // Sistema gerarchico: Citadel ha priorità se profitto sopra soglia
        if(final_profit >= min_profit_threshold_usd) {
            CTrade trade;
            double balanceBefore = AccountInfoDouble(ACCOUNT_BALANCE);
            
            if(trade.PositionClose(ticket)) {
                double balanceAfter = AccountInfoDouble(ACCOUNT_BALANCE);
                double profit = balanceAfter - balanceBefore;
                
                Print("[HIERARCHICAL EXIT] Citadel prioritario - Symbol: ", symbol, 
                      " | Ticket: ", ticket, " | Profit: $", DoubleToString(profit, 2), 
                      " | Reason: ", reason);
                
                if(MathAbs(profit) > significant_profit_threshold) {
                    Alert("CITADEL HIERARCHICAL: ", symbol, " chiuso con profitto di $", DoubleToString(profit, 2));
                }
                
                RemovePosition(ticket);
            } else {
                Print("[ERROR] Impossibile chiudere posizione - Ticket: ", ticket, " | Symbol: ", symbol, " | Errore: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
            }
        } else {
            Print("[INFO] Citadel exit rinviato - Profitto sotto soglia gerarchica: $", DoubleToString(final_profit, 2), " (min: $", DoubleToString(min_profit_threshold_usd, 2), ")");
        }
    }
};

//+------------------------------------------------------------------+
//| FUNZIONE PER CHIUSURA POSIZIONI IN PROFITTO                    |
//+------------------------------------------------------------------+
void CloseAllProfitablePositions()
{
    uint positionsCount = PositionsTotal();
    if(positionsCount == 0) return;
    
    CTrade trade;
    int closedPositions = 0;
    
    // Itera tutte le posizioni aperte dalla fine
    for(int i = (int)positionsCount - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            ulong ticket = position.Ticket();
            double profit = position.Profit();
            string symbol = position.Symbol();
            
            // Chiudi solo le posizioni in profitto
            if(profit > 0)
            {
                if(trade.PositionClose(ticket))
                {
                    closedPositions++;
                    CCitadelExitManager::RemovePosition(ticket);
                    Print("[MARKET CLOSE] Chiusa posizione in profitto - Ticket: ", ticket, " | Symbol: ", symbol, " | Profit: $", DoubleToString(profit, 2));
                }
            }
        }
    }
    
    if(closedPositions > 0)
    {
        Print("[MARKET CLOSE] Chiuse ", closedPositions, " posizioni in profitto");
        Alert("MARKET CLOSE: Chiuse ", closedPositions, " posizioni in profitto");
    }
}

//+------------------------------------------------------------------+
//| FUNZIONI PRINCIPALI DEL LIFECYCLE                              |
//+------------------------------------------------------------------+

int OnInit()
{
   TesterHideIndicators(true);
   
   symbolCount = ArraySize(SymbolNames);
   ArrayResize(dateTimeArray, TimeBack);
   ArrayResize(managedPositions, 0);
   
   double totalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double availableLiquidity = totalBalance * available_liquidity_percent;
   
   Print("[SYSTEM] EA Comparatore v2.14 inizializzato - Sistema Gerarchico Attivo");
   Print("[CONFIG] Simboli caricati: ", symbolCount);
   Print("[CONFIG] Timeframe: ", EnumToString(TimeFrame), " | Soglia aderenza: ", soglia_aderenza, "%");
   Print("[CONFIG] Indici su cui tradare: ", indici_su_cui_tradeare);
   Print("[CONFIG] Sistema Gerarchico: Citadel prioritario sopra $", DoubleToString(min_profit_threshold_usd, 2));
   Print("[CONFIG] Take Profit Safety Net: ", safety_take_profit_percent, "%");
   Print("[CONFIG] Market close alle 22:54 - Trading bloccato dalle 22:00");
   Print("[LIQUIDITY] Balance totale: $", DoubleToString(totalBalance, 2));
   Print("[LIQUIDITY] Liquidità disponibile: $", DoubleToString(availableLiquidity, 2), " (", available_liquidity_percent*100, "% del capitale)");
   
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   currentTime = TimeCurrent();
   MqlDateTime current_time_struct;
   TimeToStruct(currentTime, current_time_struct);
   
   // Aggiorna sistema Citadel ogni N tick
   tickCounter++;
   if(tickCounter >= check_frequency_ticks) {
       CCitadelExitManager::UpdateAllPositions();
       tickCounter = 0;
   }
   
   // Definisce orari operativi e di chiusura
   bool isMarketCloseTime = (current_time_struct.hour == 22 && 
                            current_time_struct.min == 54);
   
   bool isFullAnalysisTime = (current_time_struct.hour >= 17 && current_time_struct.hour <= 22) && 
                             current_time_struct.min == 30 && 
                             current_time_struct.hour < 22;
   
   bool isTradeCheckTime = ((current_time_struct.hour == 17 && current_time_struct.min > 30) || 
                         (current_time_struct.hour > 17 && current_time_struct.hour < 22)) && 
                        current_time_struct.min != 30;
   
   // Gestione market close - chiudi posizioni in profitto
   if(isMarketCloseTime && (currentTime - lastExecutionTime >= 60))
   {
      Print("[MARKET CLOSE] Chiusura posizioni in profitto alle ", TimeToString(TimeCurrent(), TIME_MINUTES));
      CloseAllProfitablePositions();
      lastExecutionTime = currentTime;
   }
   
   // Esegui analisi completa correlazioni
   if(isFullAnalysisTime && (currentTime - lastExecutionTime >= 60))
   {  
      ArrayResize(aderenceResults, 0);
      lastExecutionTime = currentTime;
      
      Print("[ANALYSIS] Avvio analisi correlazioni alle ", TimeToString(TimeCurrent(), TIME_MINUTES));
      
      CopiaDatiStorici();
      CalculateAderenza();
      OrdinaAderenceResultsPerAderenza();
      EstraiMiglioriAderenze();
      ProcessBestAdherenceAndTrade();
   }
   
   // Controlla e esegui trade basati su correlazioni
   if(isTradeCheckTime && (currentTime - lastTradeCheckTime >= 60))
   {
      lastTradeCheckTime = currentTime;
      CheckAndExecuteTrade();
   }
}

void OnDeinit(const int reason)
{
    Print("[SYSTEM] EA Comparatore v2.14 terminato - Motivo: ", reason);
    ArrayFree(managedPositions);
}

//+------------------------------------------------------------------+
//| FUNZIONI DI ANALISI TECNICA                                    |
//+------------------------------------------------------------------+

// Calcola tendenza lenta basata su SMA
bool slowIndicator(string symbol) {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(symbol, PERIOD_CURRENT, 0, SMAperiod, rates) < SMAperiod) {
      Print("[ERROR] Dati insufficienti per slowIndicator - Symbol: ", symbol, " | Richiesti: ", SMAperiod, " | Ottenuti: ", ArraySize(rates));
      return false;
   }
   
   double sum_current = 0, sum_previous = 0;
   
   // Calcola SMA corrente
   for(int i = 0; i < SMAperiod; i++) {
      sum_current += rates[i].close;
   }
   
   // Calcola SMA precedente (shift +1)
   if(CopyRates(symbol, PERIOD_CURRENT, 1, SMAperiod, rates) < SMAperiod) {
      Print("[ERROR] Dati insufficienti per slowIndicator (shift 1) - Symbol: ", symbol, " | Richiesti: ", SMAperiod, " | Ottenuti: ", ArraySize(rates));
      return false;
   }
   
   for(int i = 0; i < SMAperiod; i++) {
      sum_previous += rates[i].close;
   }
   
   double sma_current = sum_current / SMAperiod;
   double sma_previous = sum_previous / SMAperiod;
   
   // Ritorna true se SMA in crescita (uptrend)
   bool is_uptrend = (sma_current > sma_previous);
   
   return is_uptrend;
}

// Verifica tendenza veloce a un tempo specifico nel passato
bool fastIndicatorAtTime(string symbol, datetime target_time) {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Calcola shift temporale dal target time
   int shift = (int)((TimeCurrent() - target_time) / 60);
   
   if(CopyRates(symbol, PERIOD_CURRENT, shift, 1, rates) != 1) {
      Print("[ERROR] Impossibile ottenere dati per fastIndicatorAtTime - Symbol: ", symbol, " | Shift: ", shift, " | Target time: ", TimeToString(target_time));
      return false;
   }
   
   // Tendenza veloce: chiusura > apertura (candela verde)
   bool wasUptrend = (rates[0].close > rates[0].open);
   
   return wasUptrend;
}

//+------------------------------------------------------------------+
//| FUNZIONI DI TRADING PRINCIPALE                                 |
//+------------------------------------------------------------------+

// Controlla condizioni e esegue trade basati su correlazioni lag
bool CheckAndExecuteTrade()
{
   bool anyTradeExecuted = false;
   int pairsCount = ArraySize(g_slaveSymbols);
   
   if(pairsCount <= 0)
   {
      return false;
   }
   
   if(TimeCurrent() >= next_checking_time)
   {
      for(int i = 0; i < pairsCount; i++)
      {
         // Verifica accessi array sicuri
         if(i >= ArraySize(g_orderStates) || i >= ArraySize(g_masterSymbols) || 
            i >= ArraySize(g_slaveSymbols) || i >= ArraySize(g_delayTimes))
         {
            Print("[ERROR] Accesso array non valido in CheckAndExecuteTrade - Index: ", i);
            continue;
         }
         
         // Salta se ordine non attivo
         if(!g_orderStates[i])
         {
            continue;
         }
            
         string masterSymbol = g_masterSymbols[i];
         string slaveSymbol = g_slaveSymbols[i];
         int lag_minutes = g_delayTimes[i];
         
         // Evita apertura multipla sullo stesso simbolo
         if(totalPositions(slaveSymbol) > 0)
         {
            continue;
         }
         
         // Calcola tempo di controllo considerando il lag
         datetime check_time = TimeCurrent() - (lag_minutes * 60);
         
         // Verifica condizioni di trading: slow indicator su slave + fast indicator su master (tempo lag)
         if(slowIndicator(slaveSymbol) == true && fastIndicatorAtTime(masterSymbol, check_time) == true)
         {
            currentPrice = SymbolInfoDouble(slaveSymbol, SYMBOL_ASK);
            
            if(currentPrice == 0) {
               Print("[ERROR] Impossibile ottenere prezzo ASK per ", slaveSymbol);
               continue;
            }
            
            // Calcola livelli stop loss e take profit
            double stopLossPrice = currentPrice * (1 - initial_stop_percentage/100);
            double takeProfitPrice = currentPrice * (1 + safety_take_profit_percent/100);
            
            Print("[TRADE SIGNAL] Condizioni trovate per ", slaveSymbol, " basato su ", masterSymbol, " con lag ", lag_minutes, " minuti");
            
            // Invia ordine di acquisto
            ulong ticket = sendOrder(slaveSymbol, stopLossPrice, takeProfitPrice);
            
            if(ticket > 0)
            {
               Print("[TRADE OPEN] Posizione aperta per ", slaveSymbol, " a prezzo: ", DoubleToString(currentPrice, 5), " ticket #", ticket);
               
               // Aggiunge posizione al sistema gerarchico Citadel
               CCitadelExitManager::AddPosition(ticket, slaveSymbol, currentPrice);
               
               g_orderStates[i] = false;
               anyTradeExecuted = true;
            }
         }
      }
      
      // Imposta prossimo tempo di controllo
      next_checking_time = TimeCurrent() + (ulong)(60 * check_cycle);
   }
   
   return anyTradeExecuted;
}

// Invia ordine di mercato con volume ottimizzato e livelli di protezione
ulong sendOrder(string custom_symbol, double initial_stop, double takeprofit)
{
    ulong result = 0;
    
    // Calcola volume ottimale basato su gestione del rischio
    double optimalVolume = CalculateOptimalVolume(custom_symbol);
    
    if(optimalVolume == 0) {
        Print("[ERROR] Volume ottimale calcolato è zero per ", custom_symbol);
        return 0;
    }
    
    double current_price = SymbolInfoDouble(custom_symbol, SYMBOL_ASK);
    
    if(current_price == 0) {
        Print("[ERROR] Impossibile ottenere prezzo ASK per invio ordine - Symbol: ", custom_symbol);
        return 0;
    }
    
    // Invia ordine di acquisto con livelli calcolati
    bool state = trade_Buy.Buy(optimalVolume, custom_symbol, 0, initial_stop, takeprofit);
    result = trade_Buy.ResultOrder();
    
    if(!state) {
        Print("[ERROR] Ordine di acquisto fallito - Symbol: ", custom_symbol, " | Volume: ", optimalVolume, " | Errore: ", trade_Buy.ResultRetcode(), " | ", trade_Buy.ResultRetcodeDescription());
    } else {
        Print("[ORDER] Ordine eseguito - Symbol: ", custom_symbol, " | Volume: ", optimalVolume, " | SL: ", DoubleToString(initial_stop, 5), " | TP: ", DoubleToString(takeprofit, 5));
    }
    
    return result;
}

// Conta posizioni aperte per un simbolo specifico
int totalPositions(string symbol){
    uint PositionsCount = PositionsTotal();
    int count=0;
   if(PositionsCount > 0)
      {
         for(int i = (int)PositionsCount-1; i >= 0; i--)
         {
            if(position.SelectByIndex(i) && position.Symbol() == symbol)
            count++;
         }
      }
     return count;
}

// Calcola volume ottimale basato su gestione del rischio e liquidità disponibile
double CalculateOptimalVolume(string symbol)
{
   // Recupero dati di base
   double totalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double availableLiquidity = totalBalance * available_liquidity_percent;
   double maxPercentagePerTrade = (100.0 / (double)indici_su_cui_tradeare) / 100.0;
   double maxMoneyForTrade = availableLiquidity * maxPercentagePerTrade;
   
   // Log informazioni di base
   Print(StringFormat("[VOLUME DEBUG] %s - Balance: $%.2f | Liquidità: $%.2f (%.1f%%) | Max per trade: $%.2f (%.2f%%)",
                      symbol, totalBalance, availableLiquidity, available_liquidity_percent*100,
                      maxMoneyForTrade, maxPercentagePerTrade*100));
   
   // Ottieni specifiche del simbolo
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double symbolPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   if(symbolPrice == 0)
   {
      Print("[ERROR] Impossibile ottenere prezzo per calcolo volume - Symbol: ", symbol);
      return 0;
   }
   
   if(contractSize == 0)
   {
      Print("[ERROR] Contract size non valido per ", symbol, " - Contract size: ", contractSize);
      return 0;
   }
   
   // Log specifiche del simbolo
   Print(StringFormat("[SYMBOL INFO] %s - Prezzo: %.5f | Contract Size: %.0f | Min Lot: %.2f | Max Lot: %.2f | Step: %.2f",
                      symbol, symbolPrice, contractSize, minLot, maxLot, lotStep));
   
   // *** MODIFICA CRUCIALE: Forza leva 1:1 usando il valore pieno del contratto come margine ***
   double marginForOneLot = symbolPrice * contractSize; // Margine 100% = valore contratto (leva 1:1)
   
   Print(StringFormat("[MARGIN INFO] %s - Margine forzato 1:1: $%.2f | Valore contratto: $%.2f | Leva: 1:1", 
                      symbol, marginForOneLot, symbolPrice * contractSize));
   
   // Calcola volume ottimale con leva 1:1 (100% margine)
   double calculatedLots = NormalizeDouble(maxMoneyForTrade / marginForOneLot, 2);
   calculatedLots = MathFloor(calculatedLots / lotStep) * lotStep;
   calculatedLots = MathMax(calculatedLots, minLot);
   calculatedLots = MathMin(calculatedLots, maxLot);
   
   Print(StringFormat("[LOTS CALC] %s - Con leva 1:1: %.2f lots", symbol, calculatedLots));
   
   // Verifica se il volume è sotto il minimo consentito
   if(calculatedLots < minLot)
   {
      Print(StringFormat("[WARNING] Volume calcolato (%.2f) inferiore al minimo consentito (%.2f) per %s", 
                        calculatedLots, minLot, symbol));
      return 0;
   }
   
   // Ricalcola valore finale considerando il volume effettivo
   double notionalValue = calculatedLots * symbolPrice * contractSize;
   double requiredMargin = notionalValue; // Con leva 1:1, il margine è uguale al valore nozionale
   
   // Verifica finale se il capitale è sufficiente
   if(maxMoneyForTrade < requiredMargin)
   {
      Print(StringFormat("[WARNING] Capitale insufficiente per %s con leva 1:1 - Richiesto: $%.2f | Disponibile: $%.2f", 
                        symbol, requiredMargin, maxMoneyForTrade));
      
      // Ridimensiona il volume se possibile
      double maxPossibleLots = MathFloor((maxMoneyForTrade / marginForOneLot) / lotStep) * lotStep;
      
      if(maxPossibleLots >= minLot) {
         Print(StringFormat("[ADJUSTMENT] Volume ridotto a %.2f lots per rispettare leva 1:1", maxPossibleLots));
         calculatedLots = maxPossibleLots;
         
         // Aggiorna i valori dopo la riduzione
         notionalValue = calculatedLots * symbolPrice * contractSize;
         requiredMargin = notionalValue;
      } else {
         Print(StringFormat("[ERROR] Impossibile aprire posizione con leva 1:1 - Volume minimo richiederebbe $%.2f ma disponibili solo $%.2f",
                           minLot * marginForOneLot, maxMoneyForTrade));
         return 0;
      }
   }
   
   Print(StringFormat("[FINAL] %s - Volume finale: %.2f lots | Valore nozionale: $%.2f | Margine richiesto: $%.2f (%.2f%% del capitale)",
                     symbol, calculatedLots, notionalValue, requiredMargin, 
                     (requiredMargin / totalBalance) * 100));
   
   return calculatedLots;
}

//+------------------------------------------------------------------+
//| FUNZIONI DI ANALISI CORRELAZIONI                               |
//+------------------------------------------------------------------+

// Processa risultati di aderenza e prepara parametri per trading
void ProcessBestAdherenceAndTrade()
{
   int size = ArraySize(aderenceResults);
   
   if(size <= 0)
   {
      Print("[WARNING] Nessuna correlazione valida trovata dopo analisi");
      return;
   }
   
   Print("[ANALYSIS RESULT] Trovate ", size, " correlazioni valide");
   
   // Memorizza parametri per ogni correlazione trovata
   for(int i = 0; i < size; i++)
   {
      Print("[CORRELATION] Master: ", aderenceResults[i].master_symbol, " | Slave: ", aderenceResults[i].slave_symbol, " | Lag: ", aderenceResults[i].sfasamento, " minuti | Aderenza: ", DoubleToString(aderenceResults[i].aderenza, 2), "%");
      
      StoreTradeParameters(
         i,
         aderenceResults[i].sfasamento,
         aderenceResults[i].master_symbol,
         aderenceResults[i].slave_symbol
      );
   }
   
   next_checking_time = TimeCurrent() + (ulong)(60 * check_cycle);
}

// Memorizza parametri di trading per correlazione specifica
void StoreTradeParameters(int index, int delay, string master, string slave)
{
   // Ridimensiona array se necessario
   if(index >= ArraySize(g_delayTimes))
   {
      ArrayResize(g_delayTimes, index + 1);
      ArrayResize(g_masterSymbols, index + 1);
      ArrayResize(g_slaveSymbols, index + 1);
      ArrayResize(g_orderStates, index + 1);
   }
   
   // Memorizza parametri
   g_delayTimes[index] = delay;
   g_masterSymbols[index] = master;
   g_slaveSymbols[index] = slave;
   g_orderStates[index] = true;
}

// Copia dati storici per tutti i simboli nella matrice di analisi
void CopiaDatiStorici()
{
   MqlRates rates_array[];
   ArraySetAsSeries(rates_array, true);
   
   // Inizializza matrice risultati
   results.Init(TimeBack, symbolCount);
   
   int validSymbols = 0;
   int errorCount = 0;
   
   // Processa ogni simbolo
   for(int j = 0; j < symbolCount; j++)
   {
      ArrayResize(rates_array, 0);
      
      int copied = CopyRates(SymbolNames[j], TimeFrame, 0, TimeBack, rates_array);
      
      if(copied < TimeBack) {
         Print("[WARNING] Dati insufficienti per ", SymbolNames[j], " - Copiati ", copied, "/", TimeBack, " bar");
         errorCount++;
      } else {
         validSymbols++;
      }
      
      // Calcola differenze Close-Open per ogni barra e memorizza in matrice
      for(int i = 0; i < copied && i < TimeBack; i++)
      {
         double difference = rates_array[i].close - rates_array[i].open;
         results[i][j] = difference;
         
         // Memorizza timestamp solo per il primo simbolo
         if(j == 0 && i < ArraySize(dateTimeArray))
            dateTimeArray[i] = rates_array[i].time;
      }
   }
   
   Print("[DATA VALIDATION] Simboli validi: ", validSymbols, "/", symbolCount, " | Errori: ", errorCount);
}

// Calcola aderenza tra tutti i simboli per tutti gli sfasamenti
void CalculateAderenza()
{
   int numero_di_indici = symbolCount;
   double aderenza = 0;
   double scarto_medio = 0;
   int counter = 0;
   int correlationsFound = 0;

   // Itera tutti gli sfasamenti da massimo a 1
   for(int sfasamento = sfasamento_max; sfasamento > 0; sfasamento--)
   {
      // Itera simbolo di riferimento (master)
      for(int indice_di_riferimento = 0; indice_di_riferimento < numero_di_indici; indice_di_riferimento++)
      {
         // Itera simbolo da controllare (slave)
         for(int indice_da_controllare = 0; indice_da_controllare < numero_di_indici; indice_da_controllare++)
         {
            if(indice_di_riferimento != indice_da_controllare)
            {
               // Confronta movimenti per ogni periodo disponibile
               for(int n = 0; n < TimeBack - sfasamento; n++)
               {
                  // Verifica accessi sicuri alla matrice
                  if(n >= 0 && n < results.Rows() && 
                     (n + sfasamento) >= 0 && (n + sfasamento) < results.Rows() &&
                     indice_di_riferimento >= 0 && indice_di_riferimento < results.Cols() &&
                     indice_da_controllare >= 0 && indice_da_controllare < results.Cols())
                  {
                     double val_rif = results[n][indice_di_riferimento];
                     double val_control = results[n + sfasamento][indice_da_controllare];
                     
                     double prod = val_rif * val_control;
                     
                     // Conta aderenza (stesso segno = correlazione positiva)
                     if(prod > 0)
                     {
                        aderenza++;
                     }
                     
                     // Calcola scarto assoluto
                     double diff = val_rif - val_control;
                     scarto_medio += MathAbs(diff);
                     
                     counter++;
                  } else {
                     Print("[ERROR] Accesso matrice non valido - n:", n, " sfasamento:", sfasamento, " rows:", results.Rows(), " cols:", results.Cols());
                  }
               }
               
               // Calcola statistiche finali per questa coppia
               if(counter > 0)
               {
                  aderenza = (aderenza / counter) * 100.0;
                  scarto_medio = scarto_medio / counter;
                  
                  // Salva risultato se sopra soglia
                  if(aderenza > soglia_aderenza)
                  {
                     scarto_medio = MathSqrt(scarto_medio);
                     string master_symbol = SymbolNames[indice_di_riferimento];
                     string slave_symbol = SymbolNames[indice_da_controllare];

                     AderenzaResult result;
                     result.master_symbol = master_symbol;
                     result.slave_symbol = slave_symbol;
                     result.sfasamento = sfasamento;
                     result.aderenza = aderenza;
                     result.scarto_medio = scarto_medio;
                     ArrayResize(aderenceResults, ArraySize(aderenceResults) + 1);
                     aderenceResults[ArraySize(aderenceResults) - 1] = result;
                     
                     correlationsFound++;
                  }
               }
               
               // Reset contatori per prossima coppia
               aderenza = 0;
               scarto_medio = 0;
               counter = 0;
            }
         }
      }
   }
   
   Print("[ANALYSIS] Correlazioni trovate sopra soglia ", soglia_aderenza, "%: ", correlationsFound);
}

// Ordina risultati di aderenza per qualità (aderenza alta, scarto basso)
void OrdinaAderenceResultsPerAderenza()
{
    int size = ArraySize(aderenceResults);
    if (size <= 1)
        return;

    // Bubble sort ottimizzato per qualità correlazione
    for (int i = 0; i < size - 1; i++)
    {
        for (int j = i + 1; j < size; j++)
        {
            // Priorità: aderenza maggiore, poi scarto minore
            if (aderenceResults[j].aderenza > aderenceResults[i].aderenza ||
                (aderenceResults[j].aderenza == aderenceResults[i].aderenza && aderenceResults[j].scarto_medio < aderenceResults[i].scarto_medio))
            {
                AderenzaResult temp = aderenceResults[i];
                aderenceResults[i] = aderenceResults[j];
                aderenceResults[j] = temp;
            }
        }
    }
}

// Estrae le migliori correlazioni per trading (limita a numero configurato)
void EstraiMiglioriAderenze()
{
    int size = ArraySize(aderenceResults);
    if (size == 0)
    {
        Print("[WARNING] Nessuna aderenza da estrarre - Array vuoto");
        return;
    }
    
    // Limita ai migliori N risultati configurati
    int num_results = MathMin(indici_su_cui_tradeare, size);
    
    Print("[SELECTION] Selezionate le migliori ", num_results, " correlazioni su ", size, " trovate");
    
    if (num_results < size)
    {
        ArrayResize(aderenceResults, num_results);
    }
}


/*
usare VIX o US100 per farlo girare

orario impostato per funzionamento: 16:30 a 22:55 (che poi la prima ora non serve, quindi 17:30 a 22:55)

Il problema dello stop Out è serio.
Innanzitutto non sono ancora riuscito a capire come funziona la leva, ma oramai ho perso le speranze di capirlo.
Quello che è chiaro è ceh la gestione delle perdite è sbagliata.
Le possibilità che vedo sono:
- o trovo il metodo per diminuire la leva (intaccando sia i profitti che le perdite) ma non ho idea di come fare
- o elaboro un metodo di stoploss più sofisticato, che blocca le perdite priam che diventino troppo alte
- o elaboro uan sorta di timer, che mi dice ceh se una posizione non è stata chiusa dopo un tot di tempo, allora la deve chiudere e basta (magari provando a trovare un rimbalzo per diminuire le perdite ?)
- potrei anche dire: finchè sei sotto questa perdita percentuale dopo 10 minuti, allora chiudi e siamo a posto. ma devo studiare meglio dopo quanto tempo, di solito, vengono chiuse le posizioni in profitto (10 minuti?)
- o posso provare u napproccio aggressivo in cui aggredisco le perdite finchè non le pareggio
- sicuramente devo applicare un'assicuraione" sulle operazioni ancora aperte a fine giornata, o le devo chiudere costi quel che costi (magari si dice che tra le 22:30 e le 22:55 devo trovare il momento adatto per uscire)
- devo gestire meglio il numero di posizioni aperte e il numero di indici da tradeare. per adesso sono ancora connesse, ma è probabile che sia meglio disgiungerle
- potrebbe non essere uan cattiva idea apportare qualche modifica corposa e poi lanciare u'ottimizzazione genetica... magari il problema è tutto lì



problema con COINBASE comprato il 30 Gennaio, che trigghera lo stoploss a il 18 Febbraio. si può pensare ad un metodo per carpire il rmbalzo (guarda CHAT GPT)
Stessa cosa con TESLA, comprato il 07/02 e toccato stoploss il 25/02
stessa cosa per NXPSEMICONDUCTORSNV comprato il 21/02 e Stoploss il 20/03

per il crollo del 03/04/2025 il problema è diverso. 
lì c'è stata la mazzata a mercati chiusi. bisogna adottare un metodo diverso. 
magari si può pensare di andare short (vendere) sull S&P500, che ha avuto un comportamento identico ai titoli che hanno raggiundo lo stop loss
l'idea da testare potrebbe essere questa: quando chiude il mercato, si apre una posizione short sullo S&P500 con un valore equivalente alle posizioni long lasciate aperte.
Al mattino dopo, appena il mercato apre, si chiude la posizione (o la si tiene aperta finchè è in profitto, con lo stesso metodo di Citadel)

Un'altra possibilità è quella di ridurre drasticamente il valore di stoploss per le operazioni ancora aperte a fine giornata (tipo all'1% del valore alla chiusura)





// Funzione per verificare se lo spread è accettabile
bool IsSpreadAcceptable(string symbol) {
    int spread_points = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    
    // Valori di esempio, da personalizzare in base ai tuoi strumenti
    int max_acceptable_spread;
    
    // Spread massimi personalizzati per categoria di strumento
    if(StringFind(symbol, "JPY") >= 0)
        max_acceptable_spread = 20;  // Maggiore per coppie JPY
    else if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        max_acceptable_spread = 35;  // Maggiore per oro
    else if(StringFind(symbol, "US30") >= 0 || StringFind(symbol, "NAS") >= 0)
        max_acceptable_spread = 25;  // Per indici principali
    else
        max_acceptable_spread = 15;  // Default per altri strumenti
    
    if(spread_points > max_acceptable_spread) {
        Print("[SPREAD WARNING] Spread troppo alto per ", symbol, ": ", spread_points, " punti (max: ", max_acceptable_spread, ")");
        return false;
    }
    
    return true;
}

ulong sendOrder(string custom_symbol, int mode, double lot_Size, double initial_stop, double takeprofit)
{
    // Verifica spread prima di procedere
    if(!IsSpreadAcceptable(custom_symbol)) {
        Print("[TRADE SKIPPED] Spread non accettabile per ", custom_symbol);
        return 0;
    }
    
    // Resto della funzione originale...
}