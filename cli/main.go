package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/pelletier/go-toml/v2"
	"github.com/spf13/cobra"
)

// ==========================================
// 設定區
// ==========================================
var (
	workDir    string // 將在 init() 中設定為當前工作目錄
	envFile    string
	configFile string
	
	// 從環境變數讀取，如果沒有則使用預設值
	serverDomain string
	serverToken  string
)

// init 初始化工作目錄路徑（支援跨平台）
func init() {
	// 取得當前工作目錄
	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "無法取得當前目錄: %v\n", err)
		os.Exit(1)
	}
	
	// 設定 client 為工作目錄（在當前目錄下）
	workDir = filepath.Join(cwd, "client")
	envFile = filepath.Join(workDir, ".env")
	configFile = filepath.Join(workDir, "frpc.toml")
}

// ==========================================
// TOML 結構定義
// ==========================================
type FRPCConfig struct {
	ServerAddr string        `toml:"serverAddr"`
	ServerPort int           `toml:"serverPort"`
	Auth       AuthConfig    `toml:"auth"`
	Proxies    []ProxyConfig `toml:"proxies"`
}

type AuthConfig struct {
	Method string `toml:"method"`
	Token  string `toml:"token"`
}

type ProxyConfig struct {
	Name          string   `toml:"name"`
	Type          string   `toml:"type"`
	LocalIP       string   `toml:"localIP"`
	LocalPort     int      `toml:"localPort"`
	CustomDomains []string `toml:"customDomains"`
}

// ==========================================
// Docker Compose 模板
// ==========================================
const composeTemplate = `services:
  frpc:
    image: snowdreamtech/frpc:latest
    container_name: frpc
    restart: always
    network_mode: "host"
    volumes:
      - ./frpc.toml:/etc/frp/frpc.toml
      - ./logs:/var/log/frp
`

// ==========================================
// 顏色輸出
// ==========================================
const (
	colorReset  = "\033[0m"
	colorRed    = "\033[0;31m"
	colorGreen  = "\033[0;32m"
	colorYellow = "\033[1;33m"
	colorCyan   = "\033[0;36m"
)

func logInfo(msg string)  { fmt.Printf("%s[INFO]%s %s\n", colorGreen, colorReset, msg) }
func logWarn(msg string)  { fmt.Printf("%s[WARN]%s %s\n", colorYellow, colorReset, msg) }
func logError(msg string) { fmt.Printf("%s[ERROR]%s %s\n", colorRed, colorReset, msg) }

// ==========================================
// 主程式
// ==========================================
func main() {
	// 載入環境變數
	loadEnv()

	rootCmd := &cobra.Command{
		Use:   "frp-tool",
		Short: "FRP Client 通道管理工具",
	}

	// Init 指令
	initCmd := &cobra.Command{
		Use:   "init",
		Short: "初始化 FRP 客戶端環境",
		Run:   runInit,
	}
	initCmd.Flags().StringVarP(&serverDomain, "server", "s", "", "FRP 伺服器域名")
	initCmd.Flags().StringVarP(&serverToken, "token", "t", "", "驗證 Token")

	// Add 指令
	addCmd := &cobra.Command{
		Use:   "add <port> [name]",
		Short: "新增通道",
		Long:  "新增通道，若不指定 name 則自動產生隨機名稱",
		Args:  cobra.MinimumNArgs(1),
		Run:   runAdd,
	}

	// Remove 指令
	rmCmd := &cobra.Command{
		Use:     "rm <name>",
		Aliases: []string{"remove"},
		Short:   "移除通道",
		Args:    cobra.ExactArgs(1),
		Run:     runRemove,
	}

	// List 指令
	lsCmd := &cobra.Command{
		Use:     "ls",
		Aliases: []string{"list"},
		Short:   "列出所有通道",
		Run:     runList,
	}

	rootCmd.AddCommand(initCmd, addCmd, rmCmd, lsCmd)

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

// ==========================================
// 環境變數載入
// ==========================================
func loadEnv() {
	data, err := os.ReadFile(envFile)
	if err != nil {
		// 如果沒有 .env 檔案，使用預設值
		serverDomain = os.Getenv("DOMAIN")
		if serverDomain == "" {
			serverDomain = "test.mydomain.com"
		}
		return
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			val := strings.Trim(strings.TrimSpace(parts[1]), "\"'")
			if key == "DOMAIN" {
				serverDomain = val
			}
		}
	}
}

// ==========================================
// 隨機名稱產生器
// ==========================================
func generateRandomName() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// ==========================================
// Port 檢查
// ==========================================
func checkPort(port int) bool {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// ==========================================
// TOML 讀取與寫入
// ==========================================
func readConfig() (*FRPCConfig, error) {
	data, err := os.ReadFile(configFile)
	if err != nil {
		return nil, err
	}

	var config FRPCConfig
	if err := toml.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return &config, nil
}

func writeConfig(config *FRPCConfig) error {
	data, err := toml.Marshal(config)
	if err != nil {
		return err
	}

	return os.WriteFile(configFile, data, 0644)
}

// ==========================================
// Docker 操作
// ==========================================
func checkDocker() error {
	_, err := exec.LookPath("docker")
	if err != nil {
		return fmt.Errorf("找不到 docker 指令，請先安裝 Docker")
	}
	return nil
}

func startOrRestartContainer() error {
	// 檢查容器是否已存在
	checkCmd := exec.Command("docker", "compose", "ps", "-q", "frpc")
	checkCmd.Dir = workDir
	output, _ := checkCmd.Output()

	var cmd *exec.Cmd
	if len(output) > 0 {
		// 容器已存在，使用 restart
		logInfo("正在重啟 frpc...")
		cmd = exec.Command("docker", "compose", "restart", "frpc")
	} else {
		// 容器不存在，使用 up -d
		logInfo("正在啟動 frpc...")
		cmd = exec.Command("docker", "compose", "up", "-d", "frpc")
	}

	cmd.Dir = workDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// ==========================================
// Init 指令實作
// ==========================================
func runInit(cmd *cobra.Command, args []string) {
	// 檢查 Docker
	if err := checkDocker(); err != nil {
		logError(err.Error())
		os.Exit(1)
	}

	// 建立工作目錄
	if err := os.MkdirAll(workDir, 0755); err != nil {
		logError("無法建立工作目錄: " + err.Error())
		os.Exit(1)
	}

	// 建立 logs 目錄
	logsDir := filepath.Join(workDir, "logs")
	os.MkdirAll(logsDir, 0755)

	// 取得伺服器設定
	if serverDomain == "" {
		fmt.Print("請輸入 FRP 伺服器域名: ")
		fmt.Scanln(&serverDomain)
	}
	if serverToken == "" {
		fmt.Print("請輸入驗證 Token: ")
		fmt.Scanln(&serverToken)
	}

	// 儲存 .env
	envContent := fmt.Sprintf("DOMAIN=%s\nTOKEN=%s\n", serverDomain, serverToken)
	if err := os.WriteFile(envFile, []byte(envContent), 0644); err != nil {
		logError("無法寫入 .env: " + err.Error())
		os.Exit(1)
	}

	// 建立初始 frpc.toml
	config := &FRPCConfig{
		ServerAddr: serverDomain,
		ServerPort: 7000,
		Auth: AuthConfig{
			Method: "token",
			Token:  serverToken,
		},
		Proxies: []ProxyConfig{},
	}

	if err := writeConfig(config); err != nil {
		logError("無法寫入 frpc.toml: " + err.Error())
		os.Exit(1)
	}

	// 建立 docker-compose.yaml
	composeFile := filepath.Join(workDir, "docker-compose.yaml")
	if err := os.WriteFile(composeFile, []byte(composeTemplate), 0644); err != nil {
		logError("無法寫入 docker-compose.yaml: " + err.Error())
		os.Exit(1)
	}

	logInfo("✅ 初始化完成！")
	fmt.Printf("設定檔位置: %s\n", configFile)
	fmt.Println("執行 'frp-tool add <port>' 來新增通道")
}

// ==========================================
// Add 指令實作
// ==========================================
func runAdd(cmd *cobra.Command, args []string) {
	// 重新載入環境變數以確保 serverDomain 正確
	loadEnv()
	
	// 檢查 serverDomain 是否已設定
	if serverDomain == "" {
		logError("找不到 server domain，請先執行 'frp-tool init'")
		os.Exit(1)
	}
	
	// 解析 port
	portStr := args[0]
	port, err := strconv.Atoi(portStr)
	if err != nil {
		logError(fmt.Sprintf("Port '%s' 必須是數字", portStr))
		os.Exit(1)
	}

	// 決定名稱
	var name string
	if len(args) > 1 {
		name = args[1]
	} else {
		name = generateRandomName()
		logInfo("未指定名稱，已自動產生：" + name)
	}

	// 讀取設定
	config, err := readConfig()
	if err != nil {
		logError("無法讀取設定檔: " + err.Error())
		os.Exit(1)
	}

	// 檢查重複
	for _, proxy := range config.Proxies {
		if proxy.Name == name {
			logError(fmt.Sprintf("名稱 '%s' 已存在！", name))
			os.Exit(1)
		}
	}

	// 檢查 Port (僅提示)
	if !checkPort(port) {
		logWarn(fmt.Sprintf("本地 Port %d 目前似乎沒有服務在執行", port))
	}

	// 新增 Proxy
	fullDomain := fmt.Sprintf("%s.%s", name, serverDomain)
	proxy := ProxyConfig{
		Name:          name,
		Type:          "http",
		LocalIP:       "127.0.0.1",
		LocalPort:     port,
		CustomDomains: []string{fullDomain},
	}
	config.Proxies = append(config.Proxies, proxy)

	// 寫入設定
	if err := writeConfig(config); err != nil {
		logError("無法寫入設定檔: " + err.Error())
		os.Exit(1)
	}

	// 啟動/重啟容器
	if err := startOrRestartContainer(); err != nil {
		logError("啟動/重啟容器失敗: " + err.Error())
		os.Exit(1)
	}

	// 觸發 HTTPS 申請
	logInfo("正在觸發 HTTPS 申請...")
	go func() {
		exec.Command("curl", "-I", "-s", "--max-time", "3", "https://"+fullDomain).Run()
	}()

	// 輸出結果
	fmt.Println()
	fmt.Printf("%s=== 部署完成 ===%s\n", colorCyan, colorReset)
	fmt.Printf("名稱 (Name) : %s%s%s  (移除時請用此名稱)\n", colorYellow, name, colorReset)
	fmt.Printf("本地 Port   : %d\n", port)
	fmt.Printf("公開網址    : %shttps://%s%s\n", colorGreen, fullDomain, colorReset)
	fmt.Println()
}

// ==========================================
// Remove 指令實作
// ==========================================
func runRemove(cmd *cobra.Command, args []string) {
	// 重新載入環境變數
	loadEnv()
	
	name := args[0]

	// 讀取設定
	config, err := readConfig()
	if err != nil {
		logError("無法讀取設定檔: " + err.Error())
		os.Exit(1)
	}

	// 尋找並移除
	found := false
	newProxies := []ProxyConfig{}
	for _, proxy := range config.Proxies {
		if proxy.Name == name {
			found = true
			continue
		}
		newProxies = append(newProxies, proxy)
	}

	if !found {
		logError(fmt.Sprintf("找不到名稱為 '%s' 的設定", name))
		os.Exit(1)
	}

	config.Proxies = newProxies

	// 寫入設定
	if err := writeConfig(config); err != nil {
		logError("無法寫入設定檔: " + err.Error())
		os.Exit(1)
	}

	// 啟動/重啟容器
	if err := startOrRestartContainer(); err != nil {
		logError("啟動/重啟容器失敗: " + err.Error())
		os.Exit(1)
	}

	logInfo("✅ 已移除：" + name)
}

// ==========================================
// List 指令實作
// ==========================================
func runList(cmd *cobra.Command, args []string) {
	// 重新載入環境變數
	loadEnv()
	
	// 讀取設定
	config, err := readConfig()
	if err != nil {
		logError("無法讀取設定檔: " + err.Error())
		os.Exit(1)
	}

	fmt.Println()
	fmt.Printf("%s=== 活躍通道列表 ===%s\n", colorCyan, colorReset)

	if len(config.Proxies) == 0 {
		fmt.Println("目前沒有任何通道")
		fmt.Println()
		return
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "名稱 (ID)\tPort\t網址")
	fmt.Fprintln(w, "------------------------------------------------------------")

	for _, proxy := range config.Proxies {
		url := ""
		if len(proxy.CustomDomains) > 0 {
			url = "https://" + proxy.CustomDomains[0]
		}
		fmt.Fprintf(w, "%s\t%d\t%s\n", proxy.Name, proxy.LocalPort, url)
	}

	w.Flush()
	fmt.Println()
}

// ... 其他 helper function (generateRandomName, updateConfig)