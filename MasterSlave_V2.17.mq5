//+------------------------------------------------------------------+
//|                                            Comparatore_v2.17.mq5 |
//|                                                         Carmin3  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Carmin3"
#property link      "https://www.mql5.com"
#property version   "2.17"
#property description "EA v2.16 + REbound detetion system al posto del gradual exit manager"

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
input double available_liquidity_percent = 0.10; // Percentuale del capitale disponibile da utilizzare

input group "=== Parametri Citadel Exit Strategy ==="
input int ema_fast_period = 1;                 // Periodo EMA veloce [Range: 1-3]
input int ema_medium_period = 18;              // Periodo EMA media [Range: 8-15]
input int trend_confirmation_bars = 9;         // Barre consecutive per conferma trend (5 secondi per barra) [Range: 7-12]
input double min_price_change_points = 1.0;    // Variazione minima prezzo per ricalcolo (in punti)
input int check_frequency_ticks = 2;           // Frequenza controllo ogni N tick
input double initial_fluctuation_percent = 0.15; // Percentuale range fluttuazione iniziale [Range: 0.08-0.15]
input int range_exit_confirmation_ticks = 4;    // Tick consecutivi per conferma uscita range [Range: 2-5]
input double breakeven_sl_margin_percent = 0.05;// Margine percentuale sotto entry per SL
input int breakeven_timeout_minutes = 265;     // Timeout in minuti per raggiungimento breakeven

input group "=== Parametri Take Profit Gerarchico ==="
input double min_profit_threshold_usd = 5.0;   // Soglia minima profitto USD per attivazione Citadel
input double safety_take_profit_percent = 2.5; // Take Profit fisso di sicurezza (safety net)
input double citadel_profit_protection = 1.0;  // Margine di protezione profitto per Citadel

input group "=== Parametri Stop Loss ==="
input double initial_stop_percentage = 30.0;   // Percentuale iniziale stop loss

input group "=== Parametri Alert ==="
input double significant_profit_threshold = 100.0; // Soglia per alert di profitto significativo

input group "=== Parametri Rebound Detection System ==="
input double Detection_Precision = 50.0;           // [Range: 0-100] 0=cattura tutto, 100=solo certi
input int Rebound_Duration_Minutes = 5;            // [Range: 1-15] Durata massima rimbalzo breve
input double Damage_Limitation_Threshold = 10.0;   // [Range: 5-30] % minimo recupero per uscita

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
    datetime breakeven_timer_start;  // Timestamp di inizio timer breakeven
    bool breakeven_timer_active;     // Flag timer breakeven attivo
    bool is_active;                 // Flag per gestione transizione al Gradual Exit
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
private:
    static CitadelPositionData managedPositions[];
    
public:
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
        
        // Inizializzazione campi range iniziale
        newPos.upper_range_limit = entry_price * (1 + initial_fluctuation_percent/100);
        newPos.lower_range_limit = entry_price * (1 - initial_fluctuation_percent/100);
        newPos.ticks_above_range = 0;
        newPos.ticks_below_range = 0;
        newPos.initial_range_active = true;
        newPos.uptrend_confirmed = false;
        newPos.range_exit_time = 0;
        
        // Inizializzazione nuovi campi breakeven timer
        newPos.breakeven_timer_start = 0;
        newPos.breakeven_timer_active = false;
        
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
    
    static bool RemovePosition(ulong ticket) {
        int posIndex = -1;
        int size = ArraySize(managedPositions);
        
        // Trova l'indice della posizione da rimuovere
        for(int i = 0; i < size; i++) {
            if(managedPositions[i].ticket == ticket) {
                posIndex = i;
                break;
            }
        }
        
        // Se la posizione è stata trovata
        if(posIndex >= 0) {
            // Sposta tutte le posizioni successive indietro di una posizione
            for(int i = posIndex; i < size - 1; i++) {
                managedPositions[i] = managedPositions[i + 1];
            }
            
            // Riduci la dimensione dell'array
            ArrayResize(managedPositions, size - 1);
            
            Print("[CITADEL] Posizione rimossa dal sistema gerarchico - Ticket: ", ticket);
            return true;
        }
        
        Print("[ERROR] Impossibile trovare la posizione da rimuovere - Ticket: ", ticket);
        return false;
    }
    
    static void ProcessPositions() {
        int size = ArraySize(managedPositions);
        
        for(int i = 0; i < size; i++) {
            // Aggiorna EMAs
            double current_price = SymbolInfoDouble(managedPositions[i].symbol, SYMBOL_BID);
            
            // Verifica se il prezzo è cambiato abbastanza da giustificare un ricalcolo
            double price_change = MathAbs(current_price - managedPositions[i].last_price_check);
            double min_change = min_price_change_points * SymbolInfoDouble(managedPositions[i].symbol, SYMBOL_POINT);
            
            if(price_change >= min_change) {
                managedPositions[i].last_price_check = current_price;
                
                // Aggiorna i valori EMA precedenti
                managedPositions[i].ema_fast_previous = managedPositions[i].ema_fast_current;
                managedPositions[i].ema_medium_previous = managedPositions[i].ema_medium_current;
                
                // Calcola i nuovi valori EMA
                managedPositions[i].ema_fast_current = CalculateEMA(current_price, managedPositions[i].ema_fast_current, ema_fast_period);
                managedPositions[i].ema_medium_current = CalculateEMA(current_price, managedPositions[i].ema_medium_current, ema_medium_period);
                
                // Verifica il trend solo se siamo su una nuova barra
                datetime current_bar_time = iTime(managedPositions[i].symbol, PERIOD_CURRENT, 0);
                if(current_bar_time > managedPositions[i].last_bar_time) {
                    managedPositions[i].last_bar_time = current_bar_time;
                    
                    // Downtrend check
                    if(managedPositions[i].ema_fast_current < managedPositions[i].ema_medium_current) {
                        managedPositions[i].downtrend_bars_count++;
                    } else {
                        managedPositions[i].downtrend_bars_count = 0;
                    }
                    
                    // Se il downtrend è confermato per il numero specificato di barre
                    if(managedPositions[i].downtrend_bars_count >= trend_confirmation_bars) {
                        double current_profit = CalculateProfit(managedPositions[i].ticket, managedPositions[i].symbol);
                        if(current_profit > 0) {
                            if(ClosePosition(managedPositions[i].ticket, managedPositions[i].symbol)) {
                                Print("[CITADEL] Chiusura posizione per trend ribassista confermato - Ticket: ", managedPositions[i].ticket);
                                continue;
                            }
                        }
                    }
                }
                
                // Gestione del range iniziale
                if(managedPositions[i].initial_range_active) {
                    if(current_price > managedPositions[i].upper_range_limit) {
                        managedPositions[i].ticks_above_range++;
                        managedPositions[i].ticks_below_range = 0;
                        
                        // Verifica se il movimento rialzista è confermato
                        if(managedPositions[i].ticks_above_range >= range_exit_confirmation_ticks) {
                            managedPositions[i].uptrend_confirmed = true;
                            managedPositions[i].initial_range_active = false;
                            managedPositions[i].range_exit_time = TimeCurrent();
                            double sl_price = managedPositions[i].entry_price * (1 - breakeven_sl_margin_percent/100);
                            ModifyStopLoss(managedPositions[i].ticket, managedPositions[i].symbol, sl_price);
                            Print("[CITADEL] Range rotto verso l'alto - Attivato trailing stop - Ticket: ", managedPositions[i].ticket);
                        }
                    }
                    
                    else if(current_price < managedPositions[i].lower_range_limit) {
                        managedPositions[i].ticks_below_range++;
                        managedPositions[i].ticks_above_range = 0;

                        // Verifica se il movimento ribassista è confermato
                        if(managedPositions[i].ticks_below_range >= range_exit_confirmation_ticks) {
                           managedPositions[i].initial_range_active = false;
                           managedPositions[i].is_active = false;  // Disattiva gestione Citadel

                           // Passa la gestione al Rebound Detection Manager
                           CReboundDetectionManager::AddPosition(managedPositions[i].ticket, 
                                                                managedPositions[i].symbol, 
                                                                managedPositions[i].entry_price);
                    
                           Print("[CITADEL] Range rotto verso il basso - Passaggio a Rebound Detection - Ticket: ", 
                                 managedPositions[i].ticket);
                        }
                     }
                  
                   
                    else {
                        managedPositions[i].ticks_above_range = 0;
                        managedPositions[i].ticks_below_range = 0;
                    }
                }
                // Trailing stop in caso di trend rialzista confermato
                else if(managedPositions[i].uptrend_confirmed) {
                    // Calcola il tempo trascorso dall'uscita dal range
                    datetime current_time = TimeCurrent();
                    if((current_time - managedPositions[i].range_exit_time) >= 300) {  // 5 minuti
                        double current_sl = PositionGetDouble(POSITION_SL);
                        double new_sl = current_price * (1 - breakeven_sl_margin_percent/100);
                        
                        if(new_sl > current_sl) {
                            ModifyStopLoss(managedPositions[i].ticket, managedPositions[i].symbol, new_sl);
                            //Print("[CITADEL] Aggiornamento trailing stop - Ticket: ", managedPositions[i].ticket, 
                            //      " | Nuovo SL: ", DoubleToString(new_sl, 5));
                        }
                    }
                }
                // Gestione del timer di breakeven
                else if(managedPositions[i].breakeven_timer_active) {
                    datetime current_time = TimeCurrent();
                    int elapsed_minutes = (int)(current_time - managedPositions[i].breakeven_timer_start) / 60;
                    
                    // Se il tempo è scaduto
                    if(elapsed_minutes >= breakeven_timeout_minutes) {
                        double current_profit = CalculateProfit(managedPositions[i].ticket, managedPositions[i].symbol);
                        
                        // Chiudi la posizione se non ha raggiunto il breakeven
                        if(current_profit <= 0) {
                            if(ClosePosition(managedPositions[i].ticket, managedPositions[i].symbol)) {
                                Print("[CITADEL] Chiusura posizione per timeout breakeven - Ticket: ", managedPositions[i].ticket);
                                continue;
                            }
                        } else {
                            // Se in profitto, disattiva il timer e passa alla modalità normale
                            managedPositions[i].breakeven_timer_active = false;
                            Print("[CITADEL] Timer breakeven disattivato - Posizione in profitto - Ticket: ", managedPositions[i].ticket);
                        }
                    }
                }
            }
        }
    }
    
private:
    static double CalculateEMA(double price, double prev_ema, int period) {
        double multiplier = 2.0 / (period + 1);
        return (price * multiplier) + (prev_ema * (1 - multiplier));
    }
    
    static double CalculateProfit(ulong ticket, string symbol) {
        if(PositionSelectByTicket(ticket)) {
            return PositionGetDouble(POSITION_PROFIT);
        }
        return 0.0;
    }
    
    static bool ClosePosition(ulong ticket, string symbol) {
        if(PositionSelectByTicket(ticket)) {
            CTrade trade;
            return trade.PositionClose(ticket);
        }
        return false;
    }
    
    static bool ModifyStopLoss(ulong ticket, string symbol, double sl_price) {
        if(PositionSelectByTicket(ticket)) {
            CTrade trade;
            return trade.PositionModify(ticket, sl_price, PositionGetDouble(POSITION_TP));
        }
        return false;
    }
};

// Definizione array statico
CitadelPositionData CCitadelExitManager::managedPositions[];

//+------------------------------------------------------------------+
//| CLASSE REBOUND DETECTION SYSTEM - VELOCITY DECAY BASED        |
//+------------------------------------------------------------------+
class CReboundDetectionManager {
private:
    struct ReboundPositionData {
        ulong ticket;
        string symbol;
        double entry_price;
        double max_loss_price;
        double max_loss_amount;
        
        // Velocity tracking semplice
        double velocity_prev2;      // Velocità t-2
        double velocity_prev1;      // Velocità t-1  
        double velocity_current;    // Velocità t
        double price_prev;          // Prezzo precedente per calcolo velocity
        datetime time_prev;         // Timestamp precedente
        
        // Detection state
        bool rebound_detected;
        datetime detection_time;
        
        bool is_active;
    };
    
    static ReboundPositionData managedPositions[];
    
public:
    static bool AddPosition(ulong ticket, string symbol, double entry_price) {
        ReboundPositionData newPos;
        
        // Inizializzazione base
        newPos.ticket = ticket;
        newPos.symbol = symbol;
        newPos.entry_price = entry_price;
        newPos.max_loss_price = entry_price;
        newPos.max_loss_amount = 0;
        
        // Inizializzazione velocity tracking
        newPos.velocity_prev2 = 0;
        newPos.velocity_prev1 = 0;
        newPos.velocity_current = 0;
        newPos.price_prev = entry_price;
        newPos.time_prev = TimeCurrent();
        
        // Inizializzazione detection state
        newPos.rebound_detected = false;
        newPos.detection_time = 0;
        
        newPos.is_active = true;
        
        int size = ArraySize(managedPositions);
        ArrayResize(managedPositions, size + 1);
        
        if(size >= 0) {
            managedPositions[size] = newPos;
            Print("[REBOUND] Posizione aggiunta - Ticket: ", ticket, " | Symbol: ", symbol);
            return true;
        }
        
        return false;
    }
    
    static void ProcessPositions() {
        for(int i = 0; i < ArraySize(managedPositions); i++) {
            if(!managedPositions[i].is_active) continue;
            ProcessSinglePosition(managedPositions[i]);
        }
    }
    
private:
    static void ProcessSinglePosition(ReboundPositionData &pos) {
        double current_price = SymbolInfoDouble(pos.symbol, SYMBOL_BID);
        double current_profit = CalculateProfit(pos.ticket);
        
        // Aggiorna max loss
        if(current_profit < pos.max_loss_amount) {
            pos.max_loss_amount = current_profit;
            pos.max_loss_price = current_price;
        }
        
        // Exit immediato se in profitto
        if(current_profit > 0) {
            ClosePosition(pos.ticket);
            pos.is_active = false;
            Print("[REBOUND] Posizione chiusa per ritorno in profitto - Ticket: ", pos.ticket);
            return;
        }
        
        // Aggiorna velocity tracking
        UpdateVelocity(pos, current_price);
        
        if(!pos.rebound_detected) {
            // FASE DETECTION
            if(DetectRebound(pos, current_profit)) {
                pos.rebound_detected = true;
                pos.detection_time = TimeCurrent();
                Print("[REBOUND] Rimbalzo rilevato - Ticket: ", pos.ticket);
            }
        } else {
            // FASE POST-DETECTION
            if(ShouldExit(pos)) {
                ClosePosition(pos.ticket);
                pos.is_active = false;
                Print("[REBOUND] Posizione chiusa per inversione velocity - Ticket: ", pos.ticket);
            }
        }
    }
    
    static void UpdateVelocity(ReboundPositionData &pos, double current_price) {
        datetime current_time = TimeCurrent();
        double time_diff = (double)(current_time - pos.time_prev);
        
        if(time_diff > 0) {
            // Shift velocità: prev2 <- prev1 <- current <- nuovo
            pos.velocity_prev2 = pos.velocity_prev1;
            pos.velocity_prev1 = pos.velocity_current;
            pos.velocity_current = MathAbs(current_price - pos.price_prev) / time_diff;
            
            pos.price_prev = current_price;
            pos.time_prev = current_time;
        }
    }
    
    static bool DetectRebound(ReboundPositionData &pos, double current_profit) {
        // 1. Verifica velocity decay pattern
        if(pos.velocity_prev2 == 0 || pos.velocity_prev1 == 0) return false; // Dati insufficienti
        
        bool velocity_decreasing = (pos.velocity_current < pos.velocity_prev1) && 
                                  (pos.velocity_prev1 < pos.velocity_prev2);
        
        if(!velocity_decreasing) return false;
        
        // 2. Verifica recovery threshold
        double recovery_pct = CalculateRecoveryPercentage(pos, current_profit);
        double threshold = GetDynamicRecoveryThreshold();
        
        return recovery_pct >= threshold;
    }
    
    static bool ShouldExit(ReboundPositionData &pos) {
        // Exit quando velocity torna ad accelerare (inversione rimbalzo)
        return pos.velocity_current > pos.velocity_prev1;
    }
    
    static double CalculateRecoveryPercentage(const ReboundPositionData &pos, double current_profit) {
        if(pos.max_loss_amount == 0) return 0;
        return ((current_profit - pos.max_loss_amount) / MathAbs(pos.max_loss_amount)) * 100.0;
    }
    
    static double GetDynamicRecoveryThreshold() {
        return Damage_Limitation_Threshold * (1.0 + Detection_Precision/100.0);
    }
    
    static double CalculateProfit(ulong ticket) {
        if(PositionSelectByTicket(ticket)) {
            return PositionGetDouble(POSITION_PROFIT);
        }
        return 0.0;
    }
    
    static bool ClosePosition(ulong ticket) {
        if(PositionSelectByTicket(ticket)) {
            CTrade trade;
            return trade.PositionClose(ticket);
        }
        return false;
    }
    
    static bool RemovePosition(ulong ticket) {
        int posIndex = -1;
        int size = ArraySize(managedPositions);
        
        for(int i = 0; i < size; i++) {
            if(managedPositions[i].ticket == ticket) {
                posIndex = i;
                break;
            }
        }
        
        if(posIndex >= 0) {
            for(int i = posIndex; i < size - 1; i++) {
                managedPositions[i] = managedPositions[i + 1];
            }
            ArrayResize(managedPositions, size - 1);
            return true;
        }
        
        return false;
    }
};

// Definizione array statico
CReboundDetectionManager::ReboundPositionData CReboundDetectionManager::managedPositions[];

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
   
   Print("[SYSTEM] EA Comparatore v2.15 inizializzato - Sistema Gerarchico Attivo");
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
   
   // Aggiorna sistemi Citadel e Rebound ogni N tick
   tickCounter++;
   if(tickCounter >= check_frequency_ticks) {
       CCitadelExitManager::ProcessPositions();
       CReboundDetectionManager::ProcessPositions();  // Sostituisce CGradualExitManager
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
    Print("[SYSTEM] EA Comparatore v2.15 terminato - Motivo: ", reason);
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
   double totalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double availableLiquidity = totalBalance * available_liquidity_percent;
   double maxPercentagePerTrade = (100.0 / (double)indici_su_cui_tradeare) / 100.0;
   double maxMoneyForTrade = availableLiquidity * maxPercentagePerTrade;
   
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
   
   // Calcola volume ottimale
   double calculatedLots = NormalizeDouble(maxMoneyForTrade / (symbolPrice * contractSize), 2);
   calculatedLots = MathFloor(calculatedLots / lotStep) * lotStep;
   calculatedLots = MathMin(calculatedLots, maxLot);
   calculatedLots = MathMax(calculatedLots, minLot);
   
   // Verifica limiti minimi
   if(calculatedLots < minLot)
   {
      Print("[WARNING] Volume calcolato (", DoubleToString(calculatedLots, 2), ") inferiore al minimo consentito (", DoubleToString(minLot, 2), ") per ", symbol);
      return 0;
   }
   
   if(maxMoneyForTrade < (minLot * symbolPrice * contractSize))
   {
      Print("[WARNING] Capitale disponibile insufficiente per ", symbol, " - Richiesto: $", DoubleToString(minLot * symbolPrice * contractSize, 2), " | Disponibile: $", DoubleToString(maxMoneyForTrade, 2));
      return 0;
   }
   
   Print("[VOLUME] Calcolato per ", symbol, ": ", DoubleToString(calculatedLots, 2), " lots | Budget: $", DoubleToString(maxMoneyForTrade, 2));
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