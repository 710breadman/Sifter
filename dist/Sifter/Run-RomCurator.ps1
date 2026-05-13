param(
    [switch]$NoStaRelaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $NoStaRelaunch -and [Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $exe = (Get-Process -Id $PID).Path
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', $PSCommandPath, '-NoStaRelaunch')
    Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Normal
    return
}

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
try { Add-Type -AssemblyName Microsoft.VisualBasic } catch {}

$script:Root = Split-Path -Parent $PSCommandPath
$script:ModulePath = Join-Path $script:Root 'RomCurator.Core.psm1'
$script:AppName = 'Sifter'
$script:AppIconPath = Join-Path $script:Root 'assets\Sifter.ico'
Import-Module $script:ModulePath -Force -DisableNameChecking

$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Sifter" Width="1420" Height="880" MinWidth="900" MinHeight="680"
    WindowStartupLocation="CenterScreen" Background="{DynamicResource AppBackgroundBrush}">
  <Window.Resources>
    <SolidColorBrush x:Key="AppBackgroundBrush" Color="#F6F7F9"/>
    <SolidColorBrush x:Key="AppPanelBrush" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="AppSubtleBrush" Color="#E8EBEF"/>
    <SolidColorBrush x:Key="AppBorderBrush" Color="#D9DEE5"/>
    <SolidColorBrush x:Key="AppTextBrush" Color="#151A20"/>
    <SolidColorBrush x:Key="AppMutedTextBrush" Color="#5E6673"/>
    <SolidColorBrush x:Key="AppInputBrush" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="AppButtonBrush" Color="#F3F5F8"/>
    <SolidColorBrush x:Key="AppHeaderBrush" Color="#E9EDF3"/>
    <SolidColorBrush x:Key="AppSelectedBrush" Color="#2563EB"/>
    <SolidColorBrush x:Key="AppSelectedTextBrush" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="AppDisabledBrush" Color="#D5DAE2"/>
    <SolidColorBrush x:Key="AppAltRowBrush" Color="#F7F9FC"/>
    <SolidColorBrush x:Key="AppHoverBrush" Color="#E3E9F2"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.WindowBrushKey}" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.ControlBrushKey}" Color="#F3F5F8"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.ControlLightBrushKey}" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.ControlDarkBrushKey}" Color="#C9D1DD"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.WindowTextBrushKey}" Color="#151A20"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.ControlTextBrushKey}" Color="#151A20"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.GrayTextBrushKey}" Color="#5E6673"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#2563EB"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF"/>
    <Style TargetType="Button">
      <Setter Property="Margin" Value="4"/>
      <Setter Property="Padding" Value="10,5"/>
      <Setter Property="MinHeight" Value="30"/>
      <Setter Property="Background" Value="{DynamicResource AppButtonBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="{DynamicResource AppHoverBrush}"/>
        </Trigger>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Background" Value="{DynamicResource AppDisabledBrush}"/>
          <Setter Property="Foreground" Value="{DynamicResource AppMutedTextBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Margin" Value="4"/>
      <Setter Property="MinHeight" Value="28"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Background" Value="{DynamicResource AppInputBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Margin" Value="4"/>
      <Setter Property="MinHeight" Value="28"/>
      <Setter Property="Background" Value="{DynamicResource AppInputBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Background" Value="{DynamicResource AppInputBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsHighlighted" Value="True">
          <Setter Property="Background" Value="{DynamicResource AppSelectedBrush}"/>
          <Setter Property="Foreground" Value="{DynamicResource AppSelectedTextBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="Label">
      <Setter Property="Margin" Value="4,2,4,0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Margin" Value="6,4"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
    </Style>
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
    </Style>
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="{DynamicResource AppBackgroundBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Background" Value="{DynamicResource AppSubtleBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="Padding" Value="12,6"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource AppPanelBrush}"/>
          <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="{DynamicResource AppPanelBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="RowBackground" Value="{DynamicResource AppPanelBrush}"/>
      <Setter Property="AlternatingRowBackground" Value="{DynamicResource AppAltRowBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
      <Setter Property="HorizontalGridLinesBrush" Value="{DynamicResource AppBorderBrush}"/>
      <Setter Property="VerticalGridLinesBrush" Value="{DynamicResource AppBorderBrush}"/>
      <Setter Property="RowHeaderWidth" Value="0"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="{DynamicResource AppHeaderBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
      <Setter Property="Padding" Value="6,4"/>
    </Style>
    <Style TargetType="DataGridRow">
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="{DynamicResource AppHoverBrush}"/>
        </Trigger>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource AppSelectedBrush}"/>
          <Setter Property="Foreground" Value="{DynamicResource AppSelectedTextBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource AppSelectedBrush}"/>
          <Setter Property="Foreground" Value="{DynamicResource AppSelectedTextBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="ToolTip">
      <Setter Property="Background" Value="{DynamicResource AppPanelBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
    </Style>
    <Style TargetType="Expander">
      <Setter Property="Background" Value="{DynamicResource AppPanelBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppTextBrush}"/>
    </Style>
    <Style TargetType="ProgressBar">
      <Setter Property="Background" Value="{DynamicResource AppInputBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource AppSelectedBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AppBorderBrush}"/>
    </Style>
  </Window.Resources>
  <DockPanel LastChildFill="True">
    <Border DockPanel.Dock="Bottom" Background="{DynamicResource AppSubtleBrush}" Padding="8">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock x:Name="StatusText" Text="Ready" VerticalAlignment="Center" FontWeight="SemiBold"/>
          <TextBlock x:Name="BottomDetailText" Text="No cache loaded. Ready." VerticalAlignment="Center" FontSize="12"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <CheckBox x:Name="DarkModeCheck" Content="Dark Mode" Margin="8,0,12,0"/>
          <TextBlock x:Name="SummaryText" Text="0 selected" VerticalAlignment="Center" FontWeight="SemiBold"/>
        </StackPanel>
        <ProgressBar x:Name="BottomProgressBar" Grid.Row="1" Grid.ColumnSpan="2" Height="8" Minimum="0" Maximum="100" Value="0" Margin="0,6,0,0"/>
      </Grid>
    </Border>
    <TabControl x:Name="MainTabs" Margin="8">
      <TabItem Header="Paths">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <Grid Margin="14">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="220"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="120"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.ColumnSpan="3" Text="Library and export paths" FontSize="20" FontWeight="SemiBold" Margin="4,0,0,14"/>

            <Label Grid.Row="1" Content="ES-DE gamelists root"/>
            <TextBox x:Name="GamelistsRootBox" Grid.Row="1" Grid.Column="1"/>
            <Button x:Name="BrowseGamelistsButton" Grid.Row="1" Grid.Column="2" Content="Browse"/>

            <Label Grid.Row="2" Content="ROM library root"/>
            <TextBox x:Name="RomsRootBox" Grid.Row="2" Grid.Column="1"/>
            <Button x:Name="BrowseRomsButton" Grid.Row="2" Grid.Column="2" Content="Browse"/>

            <Label Grid.Row="3" Content="Media root"/>
            <TextBox x:Name="MediaRootBox" Grid.Row="3" Grid.Column="1"/>
            <Button x:Name="BrowseMediaButton" Grid.Row="3" Grid.Column="2" Content="Browse"/>

            <Label Grid.Row="4" Content="Media mode"/>
            <ComboBox x:Name="MediaModeCombo" Grid.Row="4" Grid.Column="1">
              <ComboBoxItem Content="AutoDetect"/>
              <ComboBoxItem Content="Central"/>
              <ComboBoxItem Content="BesideRoms"/>
            </ComboBox>

            <Label Grid.Row="5" Content="Export destination"/>
            <TextBox x:Name="ExportDestinationBox" Grid.Row="5" Grid.Column="1"/>
            <Button x:Name="BrowseExportButton" Grid.Row="5" Grid.Column="2" Content="Browse"/>

            <Label Grid.Row="6" Content="Export target profile"/>
            <ComboBox x:Name="ExportProfileCombo" Grid.Row="6" Grid.Column="1" DisplayMemberPath="Name" SelectedValuePath="Id"/>

            <Label Grid.Row="7" Content="Overwrite policy"/>
            <ComboBox x:Name="OverwritePolicyCombo" Grid.Row="7" Grid.Column="1">
              <ComboBoxItem Content="Skip"/>
              <ComboBoxItem Content="Overwrite"/>
              <ComboBoxItem Content="Rename"/>
              <ComboBoxItem Content="Compare"/>
            </ComboBox>

            <Label Grid.Row="8" Content="Path status"/>
            <TextBlock x:Name="PathsStatusText" Grid.Row="8" Grid.Column="1" Text="Choose folders, then validate/save paths." TextWrapping="Wrap" Margin="4"/>

            <StackPanel Grid.Row="9" Grid.Column="1" Orientation="Horizontal">
              <CheckBox x:Name="IncludeMediaDefaultCheck" Content="Include media by default"/>
              <CheckBox x:Name="IncludeGamelistDefaultCheck" Content="Write selected gamelists by default"/>
            </StackPanel>

            <StackPanel Grid.Row="10" Grid.Column="1" Orientation="Horizontal">
              <Button x:Name="ValidatePathsButton" Content="Validate paths"/>
              <Button x:Name="SaveSettingsButton" Content="Save path settings"/>
              <Button x:Name="ExportConfigButton" Content="Export config"/>
              <Button x:Name="LoadConfigButton" Content="Load config"/>
            </StackPanel>
          </Grid>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Scan Options">
        <DockPanel Margin="8">
          <Border DockPanel.Dock="Top" Background="{DynamicResource AppPanelBrush}" BorderBrush="{DynamicResource AppBorderBrush}" BorderThickness="1" Padding="8" Margin="0,0,0,8">
            <StackPanel>
              <TextBlock Text="Scan Options" FontSize="18" FontWeight="SemiBold" Margin="4,0,0,8"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="150"/>
                </Grid.ColumnDefinitions>
                <Button x:Name="QuickScanButton" Content="Discover Systems" Width="138"/>
                <Button x:Name="ScanButton" Grid.Column="1" Content="Full Scan" Width="96"/>
                <Button x:Name="CancelScanButton" Grid.Column="2" Content="Cancel" Width="90" IsEnabled="False"/>
                <ProgressBar x:Name="ScanProgressBar" Grid.Column="3" Height="18" Minimum="0" Maximum="100" Margin="8,8"/>
                <TextBlock x:Name="ScanProgressText" Grid.Column="4" Text="Idle" VerticalAlignment="Center"/>
              </Grid>
              <TextBlock Text="Deselected scan systems are not scanned. Full-system export ignores game filters and copies the selected system folder contents." TextWrapping="Wrap" Margin="4,4,0,0"/>
              <Expander x:Name="DiscoveryPanel" Header="System discovery / scan selection / full-folder export" IsExpanded="True" Visibility="Collapsed" Margin="0,8,0,0">
                <DockPanel>
                  <WrapPanel DockPanel.Dock="Top" Margin="0,0,0,4">
                    <Label Content="Scan scope"/>
                    <ComboBox x:Name="ScanScopeCombo" Width="230">
                      <ComboBoxItem Content="Scan only discovered/matched systems"/>
                      <ComboBoxItem Content="Scan selected systems only"/>
                      <ComboBoxItem Content="Scan entire ROM directory"/>
                    </ComboBox>
                    <Button x:Name="RunDiscoveredScanButton" Content="Run selected scan"/>
                    <Button x:Name="SelectAllSystemsButton" Content="Select all scan systems"/>
                    <Button x:Name="DeselectAllSystemsButton" Content="Deselect scan systems"/>
                    <Button x:Name="SelectAllFullSystemsButton" Content="Select all full exports"/>
                    <Button x:Name="DeselectAllFullSystemsButton" Content="Deselect full exports"/>
                    <Button x:Name="ExportFullSystemsButton" Content="Export selected systems"/>
                    <TextBlock x:Name="FullSystemSummaryText" Text="Full system export ignores current library filters." VerticalAlignment="Center" Margin="10,0,0,0" TextWrapping="Wrap"/>
                  </WrapPanel>
                  <DataGrid x:Name="DiscoveryGrid" Height="430" AutoGenerateColumns="False" CanUserAddRows="False" EnableRowVirtualization="True" EnableColumnVirtualization="True" CanUserSortColumns="True">
                    <DataGrid.Columns>
                      <DataGridCheckBoxColumn Header="Scan" Binding="{Binding Selected, Mode=TwoWay}" Width="58" SortMemberPath="Selected"/>
                      <DataGridCheckBoxColumn Header="Full" Binding="{Binding FullSystemSelected, Mode=TwoWay}" Width="58" SortMemberPath="FullSystemSelected"/>
                      <DataGridTextColumn Header="System" Binding="{Binding System}" Width="85" IsReadOnly="True" SortMemberPath="System"/>
                      <DataGridTextColumn Header="Display" Binding="{Binding DisplayName}" Width="130" IsReadOnly="True" SortMemberPath="DisplayName"/>
                      <DataGridTextColumn Header="Games" Binding="{Binding CopyableGames}" Width="65" IsReadOnly="True" SortMemberPath="CopyableGames"/>
                      <DataGridTextColumn Header="Est" Binding="{Binding EstimatedFileCount}" Width="55" IsReadOnly="True" SortMemberPath="EstimatedFileCount"/>
                      <DataGridTextColumn Header="Visible" Binding="{Binding VisibleGames}" Width="65" IsReadOnly="True" SortMemberPath="VisibleGames"/>
                      <DataGridTextColumn Header="Selected" Binding="{Binding SelectedCopyableGames}" Width="70" IsReadOnly="True" SortMemberPath="SelectedCopyableGames"/>
                      <DataGridTextColumn Header="Folder Size" Binding="{Binding RomSizeText}" Width="95" IsReadOnly="True" SortMemberPath="RomSize"/>
                      <DataGridTextColumn Header="Media" Binding="{Binding MediaSizeText}" Width="80" IsReadOnly="True" SortMemberPath="MediaSize"/>
                      <DataGridTextColumn Header="Dupes" Binding="{Binding DuplicateGroups}" Width="60" IsReadOnly="True"/>
                      <DataGridCheckBoxColumn Header="Gamelist" Binding="{Binding HasGamelist}" Width="75" IsReadOnly="True"/>
                      <DataGridCheckBoxColumn Header="ROMs" Binding="{Binding HasRomFolder}" Width="65" IsReadOnly="True"/>
                      <DataGridCheckBoxColumn Header="Media" Binding="{Binding HasMediaFolder}" Width="65" IsReadOnly="True"/>
                      <DataGridTextColumn Header="ROM Folder" Binding="{Binding RomSystemRoot}" Width="300" IsReadOnly="True"/>
                      <DataGridTextColumn Header="Notes" Binding="{Binding WarningsText}" Width="240" IsReadOnly="True" SortMemberPath="WarningCount"/>
                    </DataGrid.Columns>
                  </DataGrid>
                </DockPanel>
              </Expander>
            </StackPanel>
          </Border>
        </DockPanel>
      </TabItem>

      <TabItem Header="Games / Selection">
        <DockPanel>
          <Border DockPanel.Dock="Top" Background="{DynamicResource AppPanelBrush}" BorderBrush="{DynamicResource AppBorderBrush}" BorderThickness="1" Padding="8" Margin="0,0,0,8">
            <StackPanel>
              <Expander x:Name="ExcludedSystemsExpander" Header="Excluded Systems: 0" IsExpanded="False" Margin="0,6,0,0">
                <DockPanel>
                  <WrapPanel DockPanel.Dock="Top" Margin="0,0,0,4">
                    <TextBox x:Name="ExcludedSystemsSearchBox" Width="180" ToolTip="Filter systems"/>
                    <Button x:Name="ExcludeAllSystemsButton" Content="Exclude all"/>
                    <Button x:Name="IncludeAllSystemsButton" Content="Include all"/>
                    <Button x:Name="ExcludeEmptySystemsButton" Content="Exclude empty"/>
                  </WrapPanel>
                  <DataGrid x:Name="ExcludedSystemsGrid" Height="130" AutoGenerateColumns="False" CanUserAddRows="False" EnableRowVirtualization="True">
                    <DataGrid.Columns>
                      <DataGridCheckBoxColumn Header="Excluded" Binding="{Binding ExcludedFromAutoSelect, Mode=TwoWay}" Width="80"/>
                      <DataGridTextColumn Header="System" Binding="{Binding System}" Width="100" IsReadOnly="True"/>
                      <DataGridTextColumn Header="Games" Binding="{Binding CopyableGames}" Width="70" IsReadOnly="True"/>
                      <DataGridTextColumn Header="ROM GB" Binding="{Binding RomSizeGB}" Width="80" IsReadOnly="True"/>
                      <DataGridTextColumn Header="Selected" Binding="{Binding SelectedCopyableGames}" Width="80" IsReadOnly="True"/>
                    </DataGrid.Columns>
                  </DataGrid>
                </DockPanel>
              </Expander>
              <WrapPanel Margin="0,8,0,0">
                <Label Content="Search"/>
                <TextBox x:Name="SearchBox" Width="220"/>
                <Label Content="System"/>
                <ComboBox x:Name="SystemFilterCombo" Width="140"/>
                <Label Content="Score"/>
                <ComboBox x:Name="ScorePresetCombo" Width="120"/>
                <Label Content="Genre"/>
                <ComboBox x:Name="GenreFilterCombo" Width="145"/>
                <Label Content="Players"/>
                <ComboBox x:Name="PlayersFilterCombo" Width="110"/>
                <Label Content="Media"/>
                <ComboBox x:Name="MediaFilterCombo" Width="130"/>
                <CheckBox x:Name="FavoritesOnlyCheck" Content="Favorites only"/>
                <CheckBox x:Name="HasMediaCheck" Content="Has media"/>
                <CheckBox x:Name="MissingMediaCheck" Content="Missing media"/>
                <CheckBox x:Name="HasScoreCheck" Content="Has Metacritic"/>
                <CheckBox x:Name="UnmatchedOnlyCheck" Content="Unmatched Metacritic"/>
                <CheckBox x:Name="IssuesOnlyCheck" Content="Warnings"/>
                <CheckBox x:Name="SelectedOnlyCheck" Content="Selected only"/>
                <CheckBox x:Name="DuplicatesOnlyCheck" Content="Duplicate titles"/>
                <Button x:Name="ClearFiltersButton" Content="Clear filters"/>
                <TextBox x:Name="MinScoreBox" Width="1" Visibility="Collapsed"/>
                <TextBox x:Name="MaxScoreBox" Width="1" Visibility="Collapsed"/>
                <TextBox x:Name="GenreFilterBox" Width="1" Visibility="Collapsed"/>
                <TextBox x:Name="PlayersFilterBox" Width="1" Visibility="Collapsed"/>
                <ComboBox x:Name="FavoritesFilterCombo" Width="1" Visibility="Collapsed"/>
              </WrapPanel>
              <WrapPanel Margin="0,4,0,0">
                <Button x:Name="SelectVisibleButton" Content="Select visible"/>
                <Button x:Name="DeselectVisibleButton" Content="Deselect visible"/>
                <Button x:Name="InvertVisibleButton" Content="Invert visible"/>
                <Button x:Name="SelectSystemButton" Content="Select current system"/>
                <Button x:Name="ClearSelectionButton" Content="Clear selection"/>
                <Button x:Name="SaveSelectionButton" Content="Save user preset"/>
                <Button x:Name="SaveCommunityPresetButton" Content="Save community preset"/>
                <Button x:Name="LoadSelectionButton" Content="Load preset"/>
              </WrapPanel>
              <WrapPanel Margin="0,4,0,0">
                <Label Content="Auto select"/>
                <ComboBox x:Name="AutoActionCombo" Width="190"/>
                <TextBox x:Name="AutoActionValueBox" Width="70" Text="25"/>
                <CheckBox x:Name="AutoBestDuplicateOnlyCheck" Content="Best duplicate only" IsChecked="True"/>
                <CheckBox x:Name="AllowDuplicatesAcrossSystemsCheck" Content="Allow cross-system duplicates"/>
                <Button x:Name="RunLibraryAutoActionButton" Content="Apply"/>
                <TextBlock x:Name="AutoSelectInlineSummaryText" VerticalAlignment="Center" Margin="8,0,0,0"/>
              </WrapPanel>
            </StackPanel>
          </Border>

          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="*"/>
              <RowDefinition Height="190"/>
            </Grid.RowDefinitions>
            <DataGrid x:Name="LibraryGrid" Grid.Row="0" AutoGenerateColumns="False" EnableRowVirtualization="True" EnableColumnVirtualization="True"
                      VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.VirtualizationMode="Recycling" SelectionMode="Extended"
                      IsReadOnly="False" CanUserSortColumns="True" HeadersVisibility="Column" GridLinesVisibility="Horizontal"
                      Background="{DynamicResource AppPanelBrush}" BorderBrush="{DynamicResource AppBorderBrush}" BorderThickness="1">
              <DataGrid.Columns>
                <DataGridCheckBoxColumn Header="" Binding="{Binding Selected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Width="44"/>
                <DataGridTextColumn Header="System" Binding="{Binding System}" Width="80" IsReadOnly="True"/>
                <DataGridTextColumn Header="Name" Binding="{Binding CleanName}" Width="220" IsReadOnly="True"/>
                <DataGridTextColumn Header="Dupes" Binding="{Binding DuplicateGroupSize}" Width="60" IsReadOnly="True"/>
                <DataGridTextColumn Header="Original" Binding="{Binding OriginalName}" Width="180" IsReadOnly="True"/>
                <DataGridTextColumn Header="Score" Binding="{Binding CriticScore}" Width="70" IsReadOnly="True"/>
                <DataGridTextColumn Header="Conf" Binding="{Binding MatchConfidence, StringFormat={}{0:P0}}" Width="70" IsReadOnly="True"/>
                <DataGridTextColumn Header="Genre" Binding="{Binding Genre}" Width="130" IsReadOnly="True"/>
                <DataGridTextColumn Header="Players" Binding="{Binding Players}" Width="70" IsReadOnly="True"/>
                <DataGridCheckBoxColumn Header="Fav" Binding="{Binding Favorite}" Width="55" IsReadOnly="True"/>
                <DataGridTextColumn Header="Size MB" Binding="{Binding SizeMB}" Width="80" IsReadOnly="True"/>
                <DataGridCheckBoxColumn Header="Image" Binding="{Binding HasImage}" Width="65" IsReadOnly="True"/>
                <DataGridCheckBoxColumn Header="Video" Binding="{Binding HasVideo}" Width="65" IsReadOnly="True"/>
                <DataGridTextColumn Header="Issues" Binding="{Binding IssuesText}" Width="260" IsReadOnly="True"/>
                <DataGridTextColumn Header="Path" Binding="{Binding RomPath}" Width="420" IsReadOnly="True"/>
              </DataGrid.Columns>
            </DataGrid>

            <Border Grid.Row="1" Margin="0,8,0,0" Padding="8" Background="{DynamicResource AppPanelBrush}" BorderBrush="{DynamicResource AppBorderBrush}" BorderThickness="1">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="220"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="240"/>
                </Grid.ColumnDefinitions>
                <Border BorderBrush="{DynamicResource AppBorderBrush}" BorderThickness="1" Background="{DynamicResource AppSubtleBrush}">
                  <Image x:Name="PreviewImage" Stretch="Uniform"/>
                </Border>
                <TextBox x:Name="PreviewText" Grid.Column="1" Margin="8,0" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True"/>
                <StackPanel Grid.Column="2">
                  <Button x:Name="OpenRomLocationButton" Content="Open ROM location"/>
                  <Button x:Name="OpenMediaLocationButton" Content="Open media location"/>
                  <Button x:Name="SetImageButton" Content="Set image"/>
                  <Button x:Name="EditRatingButton" Content="Edit rating"/>
                </StackPanel>
              </Grid>
            </Border>
          </Grid>
        </DockPanel>
      </TabItem>

      <TabItem Header="Auto Select" Visibility="Collapsed">
        <Grid Margin="14">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="380"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <Label Content="Top N overall"/>
            <TextBox x:Name="TopNOverallBox" Text="0"/>
            <Label Content="Top N per system"/>
            <TextBox x:Name="TopNPerSystemBox" Text="0"/>
            <Label Content="Minimum score"/>
            <TextBox x:Name="AutoMinScoreBox" Text="80"/>
            <Label Content="Max total GB"/>
            <TextBox x:Name="MaxTotalGbBox" Text="0"/>
            <Label Content="Include systems (comma separated)"/>
            <TextBox x:Name="IncludeSystemsBox"/>
            <Label Content="Exclude systems (comma separated)"/>
            <TextBox x:Name="ExcludeSystemsBox"/>
            <Label Content="Include genres"/>
            <TextBox x:Name="IncludeGenresBox"/>
            <Label Content="Exclude genres"/>
            <TextBox x:Name="ExcludeGenresBox"/>
            <CheckBox x:Name="PreferFavoritesCheck" Content="Prefer favorites"/>
            <CheckBox x:Name="PreferMultiplayerCheck" Content="Prefer multiplayer"/>
            <CheckBox x:Name="ExcludeHiddenCheck" Content="Exclude hidden"/>
            <CheckBox x:Name="ExcludeKidGameCheck" Content="Exclude kid games"/>
            <CheckBox x:Name="ExcludeUnmatchedCheck" Content="Exclude unmatched ratings"/>
            <ComboBox x:Name="FillModeCombo">
              <ComboBoxItem Content="HighestScore"/>
              <ComboBoxItem Content="BestScorePerGB"/>
            </ComboBox>
            <Button x:Name="RunAutoSelectButton" Content="Apply auto-selection"/>
          </StackPanel>
          <TextBox x:Name="AutoSelectSummaryBox" Grid.Column="1" Margin="12,0,0,0" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <TabItem Header="Export">
        <DockPanel Margin="14">
          <StackPanel DockPanel.Dock="Top">
            <WrapPanel>
              <CheckBox x:Name="IncludeMediaCheck" Content="Copy media"/>
              <CheckBox x:Name="IncludeGamelistCheck" Content="Write selected gamelist.xml files"/>
              <Button x:Name="PreviewExportButton" Content="Dry-run / preview"/>
              <Button x:Name="RunExportButton" Content="Copy selected"/>
              <Button x:Name="CancelExportButton" Content="Cancel export" IsEnabled="False"/>
            </WrapPanel>
            <ProgressBar x:Name="ExportProgressBar" Height="18" Minimum="0" Maximum="100" Margin="4,8"/>
            <TextBlock x:Name="ExportProgressText" Text="No export running" Margin="4,0,0,8"/>
          </StackPanel>
          <TextBox x:Name="ExportPlanBox" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </DockPanel>
      </TabItem>

      <TabItem Header="Tools / Maintenance">
        <DockPanel Margin="8">
          <Border DockPanel.Dock="Top" Background="{DynamicResource AppPanelBrush}" BorderBrush="{DynamicResource AppBorderBrush}" BorderThickness="1" Padding="8" Margin="0,0,0,8">
            <StackPanel>
              <TextBlock x:Name="BuildInfoText" Text="Sifter" FontWeight="SemiBold" Margin="4"/>
              <TextBlock x:Name="CacheStatusText" Text="Cache: checking..." Margin="4"/>
              <TextBlock x:Name="MetacriticInfoText" Text="Metacritic: checking..." Margin="4"/>
              <WrapPanel>
                <Button x:Name="LoadCacheButton" Content="Load cached library"/>
                <Button x:Name="RefreshChangedButton" Content="Refresh changed systems"/>
                <Button x:Name="ForceFullRescanButton" Content="Force full rescan"/>
                <Button x:Name="DeleteCacheButton" Content="Delete cached library"/>
                <Button x:Name="ResetSettingsButton" Content="Reset app settings"/>
                <Button x:Name="ResetPathSettingsButton" Content="Reset path settings"/>
                <Button x:Name="OpenCacheFolderButton" Content="Open cache folder"/>
                <Button x:Name="OpenLogFolderButton" Content="Open log folder"/>
                <Button x:Name="ViewLatestLogButton" Content="View latest log"/>
                <Button x:Name="OpenAppDataFolderButton" Content="Open app data folder"/>
                <Button x:Name="UpdateMetacriticButton" Content="Update Metacritic ratings"/>
                <Button x:Name="RollbackMetacriticButton" Content="Roll back Metacritic ratings"/>
              </WrapPanel>
            </StackPanel>
          </Border>
          <TextBox x:Name="LogBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </DockPanel>
      </TabItem>
    </TabControl>
  </DockPanel>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new(([xml]$xaml))
$script:Window = [Windows.Markup.XamlReader]::Load($reader)
if (Test-Path -LiteralPath $script:AppIconPath) {
    try {
        $iconUri = [System.Uri]::new($script:AppIconPath, [System.UriKind]::Absolute)
        $script:Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconUri)
    } catch {
        Write-Warning "Could not load app icon: $($_.Exception.Message)"
    }
}

function Find-Control([string]$Name) { $script:Window.FindName($Name) }

$controls = @(
    'StatusText','BottomDetailText','BottomProgressBar','SummaryText','DarkModeCheck','GamelistsRootBox','RomsRootBox','MediaRootBox','MediaModeCombo','PathsStatusText','ExportDestinationBox',
    'ExportProfileCombo','OverwritePolicyCombo','IncludeMediaDefaultCheck','IncludeGamelistDefaultCheck',
    'BrowseGamelistsButton','BrowseRomsButton','BrowseMediaButton','BrowseExportButton','SaveSettingsButton',
    'ValidatePathsButton','ResetSettingsButton','ResetPathSettingsButton','ExportConfigButton','LoadConfigButton','LoadCacheButton','RefreshChangedButton','ForceFullRescanButton','DeleteCacheButton','OpenCacheFolderButton','OpenLogFolderButton','ViewLatestLogButton','OpenAppDataFolderButton','UpdateMetacriticButton','RollbackMetacriticButton','MetacriticInfoText','BuildInfoText','CacheStatusText','QuickScanButton','ScanButton','CancelScanButton','ScanProgressBar',
    'ScanProgressText','SearchBox','SystemFilterCombo','MinScoreBox','MaxScoreBox','GenreFilterBox','GenreFilterCombo','PlayersFilterBox','PlayersFilterCombo','ScorePresetCombo','FavoritesFilterCombo','MediaFilterCombo',
    'FavoritesOnlyCheck','HasMediaCheck','MissingMediaCheck','HasScoreCheck','SelectedOnlyCheck','UnmatchedOnlyCheck','IssuesOnlyCheck','DuplicatesOnlyCheck','ClearFiltersButton',
    'SelectVisibleButton','DeselectVisibleButton','InvertVisibleButton','SelectSystemButton','ClearSelectionButton',
    'SaveSelectionButton','SaveCommunityPresetButton','LoadSelectionButton','LibraryGrid','PreviewImage','PreviewText','OpenRomLocationButton',
    'OpenMediaLocationButton','SetImageButton','EditRatingButton','TopNOverallBox','TopNPerSystemBox','AutoMinScoreBox',
    'MaxTotalGbBox','IncludeSystemsBox','ExcludeSystemsBox','IncludeGenresBox','ExcludeGenresBox','PreferFavoritesCheck',
    'PreferMultiplayerCheck','ExcludeHiddenCheck','ExcludeKidGameCheck','ExcludeUnmatchedCheck','FillModeCombo',
    'RunAutoSelectButton','AutoSelectSummaryBox','AutoActionCombo','AutoActionValueBox','AutoBestDuplicateOnlyCheck','AllowDuplicatesAcrossSystemsCheck','AutoSelectInlineSummaryText','RunLibraryAutoActionButton','DiscoveryPanel','DiscoveryGrid','ScanScopeCombo','RunDiscoveredScanButton','SelectAllSystemsButton','DeselectAllSystemsButton','SelectAllFullSystemsButton','DeselectAllFullSystemsButton','ExportFullSystemsButton','FullSystemSummaryText','ExcludedSystemsExpander','ExcludedSystemsSearchBox','ExcludeAllSystemsButton','IncludeAllSystemsButton','ExcludeEmptySystemsButton','ExcludedSystemsGrid','IncludeMediaCheck','IncludeGamelistCheck','PreviewExportButton',
    'RunExportButton','CancelExportButton','ExportProgressBar','ExportProgressText','ExportPlanBox','LogBox','MainTabs'
)
foreach ($name in $controls) { Set-Variable -Name $name -Scope Script -Value (Find-Control $name) }

$script:AppVersion = '0.3.0'
$script:LogFolder = Get-RomCuratorLogFolder
$script:LogPath = Join-Path $script:LogFolder ("Sifter_{0}.log" -f (Get-Date -Format yyyyMMdd_HHmmss))
$script:Settings = Load-RomCuratorSettings
Initialize-RomCuratorMetacriticData -Settings $script:Settings | Out-Null
$script:LibraryItems = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:VisibleItems = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LibraryGrid.ItemsSource = $script:VisibleItems
$script:LastScanResult = $null
$script:LastCache = $null
$script:CurrentProgress = [ordered]@{ Operation='Ready'; System=''; Current=''; SystemsCompleted=0; SystemsTotal=0; GamesDiscovered=0; MetadataCount=0; MetacriticMatches=0; WarningsCount=0; StartedAt=$null }
$script:FilterTimer = $null
$script:IsRefreshingFilters = $false
$script:SystemFilterChanging = $false
$script:ScanPowerShell = $null
$script:ScanHandle = $null
$script:ScanRunspace = $null
$script:ScanCts = $null
$script:ScanQueue = $null
$script:ScanKeepExisting = $false
$script:ExportPowerShell = $null
$script:ExportHandle = $null
$script:ExportRunspace = $null
$script:ExportCts = $null
$script:ExportQueue = $null
$script:CurrentExportPlan = $null
$script:DiscoveryPowerShell = $null
$script:DiscoveryHandle = $null
$script:DiscoveryRunspace = $null
$script:DiscoveryItems = @()
$script:CachePowerShell = $null
$script:CacheHandle = $null
$script:CacheRunspace = $null
$script:CacheQuiet = $true
$script:SystemRows = @()
$script:ExcludedSystemRows = @()
$script:FullSystemSelection = New-Object System.Collections.Generic.HashSet[string]
$script:ExcludedSystems = New-Object System.Collections.Generic.HashSet[string]
$script:IsUpdatingSystemRows = $false

function Write-LogFile {
    param(
        [string]$Level = 'INFO',
        [string]$Message,
        [object]$Exception,
        [hashtable]$Context
    )
    try {
        $parts = New-Object System.Collections.Generic.List[string]
        $parts.Add("[$(Get-Date -Format o)] [$Level] $Message") | Out-Null
        if ($Context) {
            foreach ($key in $Context.Keys) { $parts.Add("  $key=$($Context[$key])") | Out-Null }
        }
        if ($Exception) {
            $ex = if ($Exception -is [System.Management.Automation.ErrorRecord]) { $Exception.Exception } else { $Exception }
            $parts.Add("  ExceptionType=$($ex.GetType().FullName)") | Out-Null
            $parts.Add("  Message=$($ex.Message)") | Out-Null
            $parts.Add("  StackTrace=$($ex.StackTrace)") | Out-Null
            if ($Exception -is [System.Management.Automation.ErrorRecord]) { $parts.Add("  ScriptStackTrace=$($Exception.ScriptStackTrace)") | Out-Null }
        }
        Add-Content -LiteralPath $script:LogPath -Value ($parts -join [Environment]::NewLine) -Encoding UTF8
    } catch {}
}

function Add-Log {
    param([string]$Message, [string]$Level = 'INFO', [object]$Exception = $null, [hashtable]$Context = $null)
    $line = "[$(Get-Date -Format HH:mm:ss)] $Message"
    Write-LogFile -Level $Level -Message $Message -Exception $Exception -Context $Context
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.ScrollToEnd()
    }
}

function Set-Status {
    param([string]$Message)
    $script:StatusText.Text = $Message
}

function Show-Error {
    param([string]$Message)
    Add-Log "ERROR: $Message" -Level 'ERROR'
    [System.Windows.MessageBox]::Show($script:Window, $Message, 'RomCurator', 'OK', 'Error') | Out-Null
}

function Get-BrushFromHex {
    param([string]$Hex)
    $converter = [System.Windows.Media.BrushConverter]::new()
    return [System.Windows.Media.Brush]$converter.ConvertFromString($Hex)
}

function Set-ThemeResource {
    param([string]$Name, [string]$Hex)
    $script:Window.Resources[$Name] = Get-BrushFromHex $Hex
}

function Get-DarkModeEnabled {
    if ($script:Settings -and $script:Settings.PSObject.Properties['DarkMode']) { return [bool]$script:Settings.DarkMode }
    if ($script:Settings -and $script:Settings.PSObject.Properties['Theme']) { return ([string]$script:Settings.Theme -ne 'Light') }
    return $true
}

function Set-ControlThemeRecursive {
    param($Control, [hashtable]$Palette)
    if ($null -eq $Control) { return }
    try {
        if ($Control -is [System.Windows.Window]) {
            $Control.Background = Get-BrushFromHex $Palette.Background
            $Control.Foreground = Get-BrushFromHex $Palette.Text
        } elseif ($Control -is [System.Windows.Controls.TextBlock]) {
            $Control.Foreground = Get-BrushFromHex $Palette.Text
        } elseif ($Control -is [System.Windows.Controls.Panel]) {
            if ($Control -isnot [System.Windows.Controls.Grid]) { $Control.Background = Get-BrushFromHex $Palette.Background }
        } elseif ($Control -is [System.Windows.Controls.Border]) {
            $Control.Background = Get-BrushFromHex $Palette.Panel
            $Control.BorderBrush = Get-BrushFromHex $Palette.Border
        } elseif ($Control -is [System.Windows.Controls.TextBox]) {
            $Control.Background = Get-BrushFromHex $Palette.Input
            $Control.Foreground = Get-BrushFromHex $Palette.Text
            $Control.BorderBrush = Get-BrushFromHex $Palette.Border
        } elseif ($Control -is [System.Windows.Controls.ComboBox]) {
            $Control.Background = Get-BrushFromHex $Palette.Input
            $Control.Foreground = Get-BrushFromHex $Palette.Text
            $Control.BorderBrush = Get-BrushFromHex $Palette.Border
        } elseif ($Control -is [System.Windows.Controls.Button]) {
            $Control.Background = Get-BrushFromHex $Palette.Button
            $Control.Foreground = Get-BrushFromHex $Palette.Text
            $Control.BorderBrush = Get-BrushFromHex $Palette.Border
        } elseif ($Control -is [System.Windows.Controls.CheckBox]) {
            $Control.Foreground = Get-BrushFromHex $Palette.Text
        } elseif ($Control -is [System.Windows.Controls.DataGrid]) {
            $Control.Background = Get-BrushFromHex $Palette.Panel
            $Control.Foreground = Get-BrushFromHex $Palette.Text
            $Control.RowBackground = Get-BrushFromHex $Palette.Panel
            $Control.AlternatingRowBackground = Get-BrushFromHex $Palette.AltRow
            $Control.HorizontalGridLinesBrush = Get-BrushFromHex $Palette.Border
            $Control.VerticalGridLinesBrush = Get-BrushFromHex $Palette.Border
        } elseif ($Control -is [System.Windows.Controls.Control]) {
            $Control.Foreground = Get-BrushFromHex $Palette.Text
        }
    } catch {}
    try {
        foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($Control)) {
            if ($child -is [System.Windows.DependencyObject]) { Set-ControlThemeRecursive -Control $child -Palette $Palette }
        }
    } catch {}
}

function Apply-AppTheme {
    param([object]$DarkMode)
    $enabled = if ($null -ne $DarkMode -and "$DarkMode" -ne '') { [bool]$DarkMode } else { Get-DarkModeEnabled }
    $palette = if (-not $enabled) {
        @{ Background='#F6F7F9'; Panel='#FFFFFF'; Subtle='#E8EBEF'; Border='#C9D1DD'; Text='#111827'; Muted='#5E6673'; Input='#FFFFFF'; Button='#F3F5F8'; Header='#E9EDF3'; Selected='#2563EB'; SelectedText='#FFFFFF'; Disabled='#D5DAE2'; AltRow='#F7F9FC' }
    } else {
        @{ Background='#0D1117'; Panel='#151B23'; Subtle='#1F2937'; Border='#3D4756'; Text='#F4F7FB'; Muted='#BAC4D0'; Input='#0F1720'; Button='#253244'; Header='#202A38'; Selected='#3B82F6'; SelectedText='#FFFFFF'; Disabled='#384252'; AltRow='#1A2330' }
    }
    Set-ThemeResource 'AppBackgroundBrush' $palette.Background
    Set-ThemeResource 'AppPanelBrush' $palette.Panel
    Set-ThemeResource 'AppSubtleBrush' $palette.Subtle
    Set-ThemeResource 'AppBorderBrush' $palette.Border
    Set-ThemeResource 'AppTextBrush' $palette.Text
    Set-ThemeResource 'AppMutedTextBrush' $palette.Muted
    Set-ThemeResource 'AppInputBrush' $palette.Input
    Set-ThemeResource 'AppButtonBrush' $palette.Button
    Set-ThemeResource 'AppHeaderBrush' $palette.Header
    Set-ThemeResource 'AppSelectedBrush' $palette.Selected
    Set-ThemeResource 'AppSelectedTextBrush' $palette.SelectedText
    Set-ThemeResource 'AppDisabledBrush' $palette.Disabled
    Set-ThemeResource 'AppAltRowBrush' $palette.AltRow
    Set-ControlThemeRecursive -Control $script:Window -Palette $palette
    Add-Log "Theme applied: darkMode=$enabled"
}

$script:Window.Dispatcher.add_UnhandledException({
    param($sender, $eventArgs)
    Add-Log 'Dispatcher unhandled exception caught; keeping app alive where possible.' -Level 'ERROR' -Exception $eventArgs.Exception
    $eventArgs.Handled = $true
    [System.Windows.MessageBox]::Show($script:Window, "An error occurred and was logged.`n`n$($eventArgs.Exception.Message)", "$script:AppName error", 'OK', 'Error') | Out-Null
})
[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $eventArgs)
    Add-Log 'AppDomain unhandled exception.' -Level 'CRITICAL' -Exception $eventArgs.ExceptionObject
})
[Threading.Tasks.TaskScheduler]::add_UnobservedTaskException({
    param($sender, $eventArgs)
    Add-Log 'Unobserved task exception.' -Level 'ERROR' -Exception $eventArgs.Exception
    $eventArgs.SetObserved()
})

function Get-ComboContent {
    param($Combo)
    if ($null -eq $Combo) { return '' }
    if ($Combo.SelectedItem -is [System.Windows.Controls.ComboBoxItem]) { return [string]$Combo.SelectedItem.Content }
    if ($Combo.SelectedValue) { return [string]$Combo.SelectedValue }
    if ($Combo.Text) { return [string]$Combo.Text }
    return ''
}

function Set-ComboByContent {
    param($Combo, [string]$Value)
    if ($null -eq $Combo) { return }
    foreach ($item in $Combo.Items) {
        if ($item -is [System.Windows.Controls.ComboBoxItem] -and [string]$item.Content -eq $Value) {
            $Combo.SelectedItem = $item
            return
        }
        $itemId = if ($item.PSObject.Properties['Id']) { $item.Id } else { $null }
        $itemName = if ($item.PSObject.Properties['Name']) { $item.Name } else { $null }
        if ($itemId -eq $Value -or $itemName -eq $Value) {
            $Combo.SelectedItem = $item
            return
        }
    }
    if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
}

function Browse-Folder {
    param([string]$InitialPath)
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    if ($InitialPath -and (Test-Path -LiteralPath $InitialPath)) { $dialog.SelectedPath = $InitialPath }
    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
    return $null
}

function Load-SettingsToUi {
    $script:GamelistsRootBox.Text = [string]$script:Settings.GamelistsRoot
    $script:RomsRootBox.Text = [string]$script:Settings.RomsRoot
    $script:MediaRootBox.Text = [string]$script:Settings.MediaRoot
    $script:ExportDestinationBox.Text = [string]$script:Settings.ExportDestination
    $script:IncludeMediaDefaultCheck.IsChecked = [bool]$script:Settings.IncludeMediaByDefault
    $script:IncludeGamelistDefaultCheck.IsChecked = [bool]$script:Settings.IncludeGamelistsByDefault
    $script:IncludeMediaCheck.IsChecked = [bool]$script:Settings.IncludeMediaByDefault
    $script:IncludeGamelistCheck.IsChecked = [bool]$script:Settings.IncludeGamelistsByDefault
    Set-ComboByContent $script:MediaModeCombo ([string]$script:Settings.MediaMode)
    if ($script:DarkModeCheck) { $script:DarkModeCheck.IsChecked = [bool](Get-DarkModeEnabled) }
    Set-ComboByContent $script:OverwritePolicyCombo ([string]$script:Settings.OverwritePolicy)
    $profiles = @(Get-RomCuratorExportProfiles -Settings $script:Settings)
    $script:ExportProfileCombo.ItemsSource = $profiles
    $script:ExportProfileCombo.SelectedValue = [string]$script:Settings.ExportProfile
    if (-not $script:ExportProfileCombo.SelectedItem -and $profiles.Count -gt 0) { $script:ExportProfileCombo.SelectedIndex = 0 }
    Set-ComboByContent $script:FillModeCombo 'HighestScore'
}

function Read-SettingsFromUi {
    $script:Settings.GamelistsRoot = $script:GamelistsRootBox.Text.Trim()
    $script:Settings.RomsRoot = $script:RomsRootBox.Text.Trim()
    $script:Settings.MediaRoot = $script:MediaRootBox.Text.Trim()
    $script:Settings.MediaMode = Get-ComboContent $script:MediaModeCombo
    if ($null -eq $script:Settings.PSObject.Properties['DarkMode']) { Add-Member -InputObject $script:Settings -NotePropertyName DarkMode -NotePropertyValue $true }
    $script:Settings.DarkMode = [bool]$script:DarkModeCheck.IsChecked
    if ($null -eq $script:Settings.PSObject.Properties['Theme']) { Add-Member -InputObject $script:Settings -NotePropertyName Theme -NotePropertyValue $(if ($script:Settings.DarkMode) { 'Dark' } else { 'Light' }) }
    $script:Settings.Theme = if ($script:Settings.DarkMode) { 'Dark' } else { 'Light' }
    $script:Settings.ExportDestination = $script:ExportDestinationBox.Text.Trim()
    $script:Settings.ExportProfile = [string]$script:ExportProfileCombo.SelectedValue
    $script:Settings.OverwritePolicy = Get-ComboContent $script:OverwritePolicyCombo
    $script:Settings.IncludeMediaByDefault = [bool]$script:IncludeMediaDefaultCheck.IsChecked
    $script:Settings.IncludeGamelistsByDefault = [bool]$script:IncludeGamelistDefaultCheck.IsChecked
    Sync-SystemStateFromRows
    return $script:Settings
}

function Test-ConfiguredPaths {
    $missing = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($script:GamelistsRootBox.Text) -or -not (Test-Path -LiteralPath $script:GamelistsRootBox.Text)) { $missing.Add('ES-DE gamelists root') }
    if ([string]::IsNullOrWhiteSpace($script:RomsRootBox.Text) -or -not (Test-Path -LiteralPath $script:RomsRootBox.Text)) { $missing.Add('ROM library root') }
    $mediaMode = Get-ComboContent $script:MediaModeCombo
    if ($mediaMode -eq 'Central' -and ([string]::IsNullOrWhiteSpace($script:MediaRootBox.Text) -or -not (Test-Path -LiteralPath $script:MediaRootBox.Text))) { $missing.Add('Media root for central media mode') }
    if ($missing.Count -gt 0) {
        [System.Windows.MessageBox]::Show($script:Window, "These paths are missing or invalid:`n$($missing -join "`n")", 'Preflight warning', 'OK', 'Warning') | Out-Null
        Add-Log "Preflight failed: $($missing -join ', ')" -Level 'WARN'
        return $false
    }
    $systems = @(Get-RomCuratorDiscoveredSystems -Settings (Read-SettingsFromUi))
    if ($systems.Count -eq 0) {
        Add-Log 'Preflight found no systems.' -Level 'WARN'
    } else {
        Add-Log "Preflight systems discovered: $($systems.Count)"
    }
    return $true
}

function Reorder-MainTabs {
    try {
        $tabs = $script:MainTabs
        if (-not $tabs) { return }
        $paths = $null
        $tools = $null
        foreach ($item in @($tabs.Items)) {
            if ([string]$item.Header -eq 'Paths') { $paths = $item }
            if ([string]$item.Header -eq 'Tools / Maintenance') { $tools = $item }
        }
        if ($paths -and $tabs.Items.IndexOf($paths) -ne 0) {
            $tabs.Items.Remove($paths)
            $tabs.Items.Insert(0, $paths)
        }
        if ($tools -and $tabs.Items.IndexOf($tools) -ne ($tabs.Items.Count - 1)) {
            $tabs.Items.Remove($tools)
            $tabs.Items.Add($tools) | Out-Null
        }
        $tabs.SelectedIndex = 0
    } catch {
        Add-Log 'Tab reordering failed.' -Level 'WARN' -Exception $_
    }
}

function Update-CacheStatusText {
    try {
        $cachePath = Get-RomCuratorLibraryCachePath
        if (Test-Path -LiteralPath $cachePath) {
            $item = Get-Item -LiteralPath $cachePath
            $mb = [Math]::Round($item.Length / 1MB, 2)
            $script:CacheStatusText.Text = "Cache: $mb MB | $($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) | $cachePath"
        } else {
            $script:CacheStatusText.Text = "Cache: no cached library found"
        }
    } catch {
        if ($script:CacheStatusText) { $script:CacheStatusText.Text = "Cache: status unavailable" }
    }
}

function Get-IntBox($Box, [int]$Default = 0) {
    $value = 0
    if ([int]::TryParse($Box.Text, [ref]$value)) { return $value }
    return $Default
}

function Get-DoubleBox($Box, [double]$Default = 0) {
    $value = 0.0
    if ([double]::TryParse($Box.Text, [ref]$value)) { return $value }
    return $Default
}

function Split-ListText([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    return @($Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Initialize-UiDropdowns {
    $script:SystemFilterCombo.ItemsSource = @('All')
    $script:SystemFilterCombo.SelectedIndex = 0
    $script:GenreFilterCombo.ItemsSource = @('All')
    $script:GenreFilterCombo.SelectedIndex = 0
    $script:PlayersFilterCombo.ItemsSource = @('All')
    $script:PlayersFilterCombo.SelectedIndex = 0
    $script:ScorePresetCombo.ItemsSource = @('Any score','90+','80+','70+','Unmatched')
    $script:ScorePresetCombo.SelectedIndex = 0
    $script:FavoritesFilterCombo.ItemsSource = @('All games','Favorites only','Not favorites')
    $script:FavoritesFilterCombo.SelectedIndex = 0
    $script:MediaFilterCombo.ItemsSource = @('Any media','Has any media','No media','Missing image','Missing video','Has image','Has video')
    $script:MediaFilterCombo.SelectedIndex = 0
    $script:AutoActionCombo.ItemsSource = @('Top N overall','Top N per system','Score threshold','Fill size GB','Best score per GB size GB')
    $script:AutoActionCombo.SelectedIndex = 0
    if ($script:ScanScopeCombo) { $script:ScanScopeCombo.SelectedIndex = 0 }
}

function Update-MetacriticInfo {
    $info = Get-RomCuratorMetacriticInfo -Path $script:Settings.RatingFilePath
    $script:MetacriticInfoText.Text = "Metacritic: $($info.Version) | $($info.Path)"
    return $info
}

function ConvertTo-UiList {
    param([object]$Collection)
    @($Collection)
}

function Get-UiProperty {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Set-UiProperty {
    param($Object, [string]$Name, $Value)
    if ($null -eq $Object) { return }
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
    } else {
        $Object.$Name = $Value
    }
}

function Ensure-LibraryItemUiShape {
    param($Item)
    if ($null -eq $Item) { return $null }
    $defaults = [ordered]@{
        Selected=$false; System=''; CleanName=''; OriginalName=''; CriticScore=$null; MatchConfidence=$null;
        RatingTitleMatched=''; RatingPlatform=''; RatingReleaseYear=$null; RatingUrl=''; RatingMatchMethod='';
        Genre=''; Players=''; Favorite=''; Hidden=''; KidGame=''; Description=''; Developer=''; Publisher='';
        ReleaseDate=''; FileSize=[int64]0; SizeMB=0; Extension=''; ParentFolder=''; ModifiedDate=$null;
        RomPath=''; RelativePath=''; IsFolder=$false; HasImage=$false; HasVideo=$false; ImagePath='';
        ThumbnailPath=''; MarqueePath=''; VideoPath=''; FanartPath=''; BoxartPath=''; MediaSize=[int64]0;
        Issues=@(); IssuesText=''; Metadata=[ordered]@{}; NormalizedName=''; DuplicateKey=''; DuplicateGroupSize=1;
        IsDuplicate=$false; DuplicateRank=1; DuplicateNote=''; PresetMatchStatus=''
    }
    foreach ($key in $defaults.Keys) {
        if ($null -eq $Item.PSObject.Properties[$key]) { Add-Member -InputObject $Item -NotePropertyName $key -NotePropertyValue $defaults[$key] -Force }
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-UiProperty $Item 'CleanName' ''))) {
        Set-UiProperty $Item 'CleanName' (Normalize-RomCuratorGameName (Get-UiProperty $Item 'OriginalName' ''))
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-UiProperty $Item 'NormalizedName' ''))) {
        Set-UiProperty $Item 'NormalizedName' (Normalize-RomCuratorGameName -Name (Get-UiProperty $Item 'CleanName' '') -ForKey)
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-UiProperty $Item 'DuplicateKey' ''))) {
        Set-UiProperty $Item 'DuplicateKey' (Get-UiProperty $Item 'NormalizedName' '')
    }
    if (-not (Get-UiProperty $Item 'SizeMB' $null)) {
        Set-UiProperty $Item 'SizeMB' ([Math]::Round(([double](Get-UiProperty $Item 'FileSize' 0) / 1MB), 2))
    }
    return $Item
}

function Update-UiDuplicateGroups {
    try {
        Update-RomCuratorDuplicateGroups -Items @(ConvertTo-UiList $script:LibraryItems) | Out-Null
    } catch {
        Add-Log 'Duplicate grouping failed.' -Level 'WARN' -Exception $_
    }
}

function Add-LibraryItems {
    param([object[]]$Items, [switch]$ReplaceSystem, [string]$System)
    if ($ReplaceSystem -and $System) {
        for ($i = $script:LibraryItems.Count - 1; $i -ge 0; $i--) {
            if ($script:LibraryItems[$i].System -eq $System) { $script:LibraryItems.RemoveAt($i) }
        }
        $script:VisibleItems = @($script:VisibleItems | Where-Object { $_.System -ne $System })
    }
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        [void](Ensure-LibraryItemUiShape $item)
        $script:LibraryItems.Add($item)
    }
    Update-UiDuplicateGroups
    Refresh-SystemFilter -PreserveSelection
    Refresh-DynamicFilterDropdowns
    Apply-Filters
    Update-Summary
}

function Set-LibraryItems {
    param([object[]]$Items)
    $script:LibraryItems.Clear()
    $script:VisibleItems = @()
    $script:LibraryGrid.ItemsSource = $script:VisibleItems
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        [void](Ensure-LibraryItemUiShape $item)
        $script:LibraryItems.Add($item)
    }
    Update-UiDuplicateGroups
    Refresh-SystemFilter
    Refresh-DynamicFilterDropdowns
    Apply-Filters
}

function Refresh-SystemFilter {
    param([switch]$PreserveSelection)
    $current = Get-ComboContent $script:SystemFilterCombo
    $systems = @('All') + @(ConvertTo-UiList $script:LibraryItems | Where-Object { $_ -and $_.System } | Select-Object -ExpandProperty System -Unique | Sort-Object)
    try {
        $script:SystemFilterChanging = $true
        $script:SystemFilterCombo.ItemsSource = $systems
        if ($PreserveSelection -and $systems -contains $current) { $script:SystemFilterCombo.SelectedItem = $current }
        elseif ($systems.Count -gt 0) { $script:SystemFilterCombo.SelectedIndex = 0 }
    } catch {
        Add-Log 'System dropdown refresh failed.' -Level 'ERROR' -Exception $_
    } finally {
        $script:SystemFilterChanging = $false
    }
}

function Refresh-DynamicFilterDropdowns {
    try {
        $genres = @('All') + @(ConvertTo-UiList $script:LibraryItems | Where-Object { $_.Genre } | ForEach-Object {
            $_.Genre -split '[,/;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        } | Select-Object -Unique | Sort-Object)
        $players = @('All') + @(ConvertTo-UiList $script:LibraryItems | Where-Object { $_.Players } | Select-Object -ExpandProperty Players -Unique | Sort-Object)
        $currentGenre = Get-ComboContent $script:GenreFilterCombo
        $currentPlayers = Get-ComboContent $script:PlayersFilterCombo
        $script:GenreFilterCombo.ItemsSource = $genres
        $script:PlayersFilterCombo.ItemsSource = $players
        if ($genres -contains $currentGenre) { $script:GenreFilterCombo.SelectedItem = $currentGenre } else { $script:GenreFilterCombo.SelectedIndex = 0 }
        if ($players -contains $currentPlayers) { $script:PlayersFilterCombo.SelectedItem = $currentPlayers } else { $script:PlayersFilterCombo.SelectedIndex = 0 }
    } catch {
        Add-Log 'Dynamic filter dropdown refresh failed.' -Level 'ERROR' -Exception $_
    }
}

function Test-ItemVisible {
    param($Item)
    if ($null -eq $Item) { return $false }
    $search = if ($script:SearchBox) { $script:SearchBox.Text.Trim() } else { '' }
    $system = Get-ComboContent $script:SystemFilterCombo
    $minScore = Get-IntBox $script:MinScoreBox 0
    $maxScore = Get-IntBox $script:MaxScoreBox 0
    $genreText = if ($script:GenreFilterBox) { $script:GenreFilterBox.Text.Trim() } else { '' }
    $genreDrop = Get-ComboContent $script:GenreFilterCombo
    $playersText = if ($script:PlayersFilterBox) { $script:PlayersFilterBox.Text.Trim() } else { '' }
    $playersDrop = Get-ComboContent $script:PlayersFilterCombo
    $scorePreset = Get-ComboContent $script:ScorePresetCombo
    $favFilter = Get-ComboContent $script:FavoritesFilterCombo
    $mediaFilter = Get-ComboContent $script:MediaFilterCombo
    $cleanName = [string](Get-UiProperty $Item 'CleanName' '')
    $originalName = [string](Get-UiProperty $Item 'OriginalName' '')
    $romPath = [string](Get-UiProperty $Item 'RomPath' '')
    $itemSystem = [string](Get-UiProperty $Item 'System' '')
    $itemGenre = [string](Get-UiProperty $Item 'Genre' '')
    $itemPlayers = [string](Get-UiProperty $Item 'Players' '')
    $hasImage = [bool](Get-UiProperty $Item 'HasImage' $false)
    $hasVideo = [bool](Get-UiProperty $Item 'HasVideo' $false)
    $favorite = "$(Get-UiProperty $Item 'Favorite' '')" -match '(?i)true|1|yes'
    $scoreValue = Get-UiProperty $Item 'CriticScore' $null
    $hasScore = $null -ne $scoreValue -and "$scoreValue" -ne ''

    if ($search -and "$cleanName $originalName $romPath" -notlike "*$search*") { return $false }
    if ($system -and $system -ne 'All' -and $itemSystem -ne $system) { return $false }
    if ($minScore -gt 0 -and (-not $hasScore -or [int]$scoreValue -lt $minScore)) { return $false }
    if ($maxScore -gt 0 -and (-not $hasScore -or [int]$scoreValue -gt $maxScore)) { return $false }
    if ($genreText -and "$itemGenre" -notlike "*$genreText*") { return $false }
    if ($genreDrop -and $genreDrop -ne 'All' -and "$itemGenre" -notlike "*$genreDrop*") { return $false }
    if ($playersText -and "$itemPlayers" -notlike "*$playersText*") { return $false }
    if ($playersDrop -and $playersDrop -ne 'All' -and "$itemPlayers" -ne $playersDrop) { return $false }
    if ($scorePreset -eq '90+' -and (-not $hasScore -or [int]$scoreValue -lt 90)) { return $false }
    if ($scorePreset -eq '80+' -and (-not $hasScore -or [int]$scoreValue -lt 80)) { return $false }
    if ($scorePreset -eq '70+' -and (-not $hasScore -or [int]$scoreValue -lt 70)) { return $false }
    if ($scorePreset -eq 'Unmatched' -and $hasScore) { return $false }
    if ($favFilter -eq 'Favorites only' -and -not $favorite) { return $false }
    if ($favFilter -eq 'Not favorites' -and $favorite) { return $false }
    if ($mediaFilter -eq 'Has any media' -and -not ($hasImage -or $hasVideo)) { return $false }
    if ($mediaFilter -eq 'No media' -and ($hasImage -or $hasVideo)) { return $false }
    if ($mediaFilter -eq 'Missing image' -and $hasImage) { return $false }
    if ($mediaFilter -eq 'Missing video' -and $hasVideo) { return $false }
    if ($mediaFilter -eq 'Has image' -and -not $hasImage) { return $false }
    if ($mediaFilter -eq 'Has video' -and -not $hasVideo) { return $false }
    if ($script:FavoritesOnlyCheck.IsChecked -and -not $favorite) { return $false }
    if ($script:HasMediaCheck -and $script:HasMediaCheck.IsChecked -and -not ($hasImage -or $hasVideo)) { return $false }
    if ($script:MissingMediaCheck.IsChecked -and ($hasImage -or $hasVideo)) { return $false }
    if ($script:HasScoreCheck -and $script:HasScoreCheck.IsChecked -and -not $hasScore) { return $false }
    if ($script:SelectedOnlyCheck.IsChecked -and -not [bool](Get-UiProperty $Item 'Selected' $false)) { return $false }
    if ($script:UnmatchedOnlyCheck.IsChecked -and $hasScore) { return $false }
    if ($script:IssuesOnlyCheck.IsChecked -and [string]::IsNullOrWhiteSpace([string](Get-UiProperty $Item 'IssuesText' ''))) { return $false }
    if ($script:DuplicatesOnlyCheck -and $script:DuplicatesOnlyCheck.IsChecked -and -not [bool](Get-UiProperty $Item 'IsDuplicate' $false)) { return $false }
    return $true
}

function Apply-Filters {
    if ($script:IsRefreshingFilters) { return }
    try {
        $started = Get-Date
        $script:IsRefreshingFilters = $true
        $visible = New-Object System.Collections.Generic.List[object]
        foreach ($item in ConvertTo-UiList $script:LibraryItems) {
            if (Test-ItemVisible $item) { [void]$visible.Add($item) }
        }
        $script:VisibleItems = @($visible.ToArray())
        $script:LibraryGrid.ItemsSource = $script:VisibleItems
        Update-Summary
        Update-SystemRows
        if ($script:VisibleItems.Count -eq 0) {
            Set-Status 'No games match the current filters.'
        }
        $duration = ((Get-Date) - $started).TotalMilliseconds
        if ($duration -gt 150) { Add-Log "Filter applied: visible=$($script:VisibleItems.Count), total=$($script:LibraryItems.Count), ms=$([Math]::Round($duration,1))" }
    } catch {
        Add-Log 'Apply-Filters failed.' -Level 'ERROR' -Exception $_ -Context @{ System=(Get-ComboContent $script:SystemFilterCombo); Search=$script:SearchBox.Text }
    } finally {
        $script:IsRefreshingFilters = $false
    }
}

function Schedule-ApplyFilters {
    if (-not $script:FilterTimer) {
        $script:FilterTimer = [System.Windows.Threading.DispatcherTimer]::new()
        $script:FilterTimer.Interval = [TimeSpan]::FromMilliseconds(250)
        $script:FilterTimer.Add_Tick({
            $script:FilterTimer.Stop()
            Apply-Filters
        })
    }
    $script:FilterTimer.Stop()
    $script:FilterTimer.Start()
}

function Update-Summary {
    $started = Get-Date
    $summary = Get-RomCuratorSelectionSummary -Items @(ConvertTo-UiList $script:LibraryItems)
    $script:SummaryText.Text = "$($summary.CopyableSelectedCount) copyable selected | ROM $($summary.RomSizeGB) GB | media $($summary.MediaSizeGB) GB | total $($summary.TotalSizeGB) GB"
    Set-Status "$($script:VisibleItems.Count) visible of $($script:LibraryItems.Count) games"
    $duration = ((Get-Date) - $started).TotalMilliseconds
    if ($duration -gt 150) { Add-Log "Selection summary recalculated in $([Math]::Round($duration,1)) ms" }
}

function Get-SettingsExcludedSystems {
    if ($script:Settings -and $script:Settings.PSObject.Properties['ExcludedSystems']) { return @($script:Settings.ExcludedSystems) }
    return @()
}

function Sync-SystemStateFromRows {
    if ($script:IsUpdatingSystemRows) { return }
    if (-not $script:SystemRows -or @($script:SystemRows).Count -eq 0) {
        if ($null -ne $script:Settings -and $script:Settings.PSObject.Properties['ExcludedSystems']) {
            $script:ExcludedSystems.Clear()
            foreach ($system in @($script:Settings.ExcludedSystems)) { if ($system) { [void]$script:ExcludedSystems.Add([string]$system) } }
        }
        return
    }
    $script:ExcludedSystems.Clear()
    $script:FullSystemSelection.Clear()
    foreach ($row in @($script:SystemRows)) {
        if ($row.ExcludedFromAutoSelect) { [void]$script:ExcludedSystems.Add([string]$row.System) }
        if ($row.FullSystemSelected) { [void]$script:FullSystemSelection.Add([string]$row.System) }
    }
    if ($null -eq $script:Settings.PSObject.Properties['ExcludedSystems']) { Add-Member -InputObject $script:Settings -NotePropertyName ExcludedSystems -NotePropertyValue @() }
    $script:Settings.ExcludedSystems = @($script:ExcludedSystems)
}

function Ensure-SystemRowUiShape {
    param($Row)
    if ($null -eq $Row) { return $null }
    $defaults = [ordered]@{
        System=''; DisplayName=''; Selected=$true; FullSystemSelected=$false; ExcludedFromAutoSelect=$false; RomSystemRoot='';
        HasGamelist=$false; HasRomFolder=$true; HasMediaFolder=$false; EstimatedFileCount=0;
        TotalEntries=0; CopyableGames=0; MatchedGamelistEntries=0; MissingRomEntries=0; OrphanRoms=0;
        SelectedGames=0; SelectedCopyableGames=0; VisibleGames=0; DuplicateGroups=0; DuplicateItems=0;
        RomSize=[int64]0; RomSizeGB=0; RomSizeText='0 B'; SelectedRomSize=[int64]0; SelectedRomSizeGB=0; SelectedRomSizeText='0 B'; MediaSize=[int64]0; MediaSizeGB=0; MediaSizeText='0 B';
        WarningCount=0; WarningsText=''
    }
    foreach ($key in $defaults.Keys) {
        if ($null -eq $Row.PSObject.Properties[$key]) { Add-Member -InputObject $Row -NotePropertyName $key -NotePropertyValue $defaults[$key] -Force }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Row.DisplayName)) { $Row.DisplayName = [string]$Row.System }
    return $Row
}

function Refresh-ExcludedSystemsGrid {
    $search = if ($script:ExcludedSystemsSearchBox) { $script:ExcludedSystemsSearchBox.Text.Trim() } else { '' }
    $rows = @($script:SystemRows | Where-Object { -not $search -or "$($_.System) $($_.DisplayName)" -like "*$search*" })
    $script:ExcludedSystemRows = $rows
    if ($script:ExcludedSystemsGrid) { $script:ExcludedSystemsGrid.ItemsSource = $script:ExcludedSystemRows }
}

function Update-SystemSelectionSummaries {
    Sync-SystemStateFromRows
    $excludedCount = $script:ExcludedSystems.Count
    $includedCount = [Math]::Max(0, @($script:SystemRows).Count - $excludedCount)
    if ($script:ExcludedSystemsExpander) { $script:ExcludedSystemsExpander.Header = "Excluded Systems: $excludedCount ($includedCount included)" }
    $fullSummary = Get-RomCuratorFullSystemSelectionSummary -Items @(ConvertTo-UiList $script:LibraryItems) -Systems @($script:FullSystemSelection)
    if ($script:FullSystemSummaryText) {
        $script:FullSystemSummaryText.Text = "Full system export ignores current library filters. Selected systems: $($fullSummary.SystemCount) | games $($fullSummary.GameCount) | ROM $($fullSummary.RomSizeGB) GB | media $($fullSummary.MediaSizeGB) GB"
    }
}

function Update-SystemRows {
    param([object[]]$DiscoveryRows)
    $started = Get-Date
    try {
        Sync-SystemStateFromRows
        if ($script:ExcludedSystems.Count -eq 0) {
            foreach ($system in @(Get-SettingsExcludedSystems)) { if ($system) { [void]$script:ExcludedSystems.Add([string]$system) } }
        }
        $rows = @()
        if ($script:LibraryItems.Count -gt 0) {
            $rows = @(Get-RomCuratorSystemSummaries -Items @(ConvertTo-UiList $script:LibraryItems) -VisibleItems @(ConvertTo-UiList $script:VisibleItems) -ExcludedSystems @($script:ExcludedSystems) -FullSelectedSystems @($script:FullSystemSelection))
        } elseif ($DiscoveryRows) {
            $rows = @($DiscoveryRows)
        } elseif ($script:DiscoveryItems) {
            $rows = @($script:DiscoveryItems)
        }
        $script:IsUpdatingSystemRows = $true
        foreach ($row in $rows) {
            [void](Ensure-SystemRowUiShape $row)
            $row.ExcludedFromAutoSelect = $script:ExcludedSystems.Contains([string]$row.System)
            $row.FullSystemSelected = $script:FullSystemSelection.Contains([string]$row.System)
        }
        $script:SystemRows = @(Sort-RomCuratorSystemRows -Rows $rows -By System)
        $script:DiscoveryGrid.ItemsSource = $script:SystemRows
        Refresh-ExcludedSystemsGrid
        $script:DiscoveryPanel.Visibility = if ($script:SystemRows.Count -gt 0) { 'Visible' } else { 'Collapsed' }
        $script:IsUpdatingSystemRows = $false
        Update-SystemSelectionSummaries
        $duration = ((Get-Date) - $started).TotalMilliseconds
        Add-Log "System counts calculated: systems=$($script:SystemRows.Count), ms=$([Math]::Round($duration,1))"
    } catch {
        $script:IsUpdatingSystemRows = $false
        Add-Log 'System row update failed.' -Level 'ERROR' -Exception $_
    }
}

function Show-SelectedPreview {
    $item = $script:LibraryGrid.SelectedItem
    if (-not $item) {
        $script:PreviewText.Text = ''
        $script:PreviewImage.Source = $null
        return
    }
    $script:PreviewText.Text = @(
        "$($item.CleanName) [$($item.System)]"
        "Original: $($item.OriginalName)"
        "Score: $($item.CriticScore) | Match: $($item.RatingTitleMatched) ($($item.MatchConfidence))"
        "Genre: $($item.Genre) | Players: $($item.Players) | Favorite: $($item.Favorite)"
        "Size: $($item.SizeMB) MB"
        "ROM: $($item.RomPath)"
        "Image: $($item.ImagePath)"
        "Video: $($item.VideoPath)"
        "Issues: $($item.IssuesText)"
        ''
        $item.Description
    ) -join [Environment]::NewLine
    $image = @($item.ImagePath, $item.ThumbnailPath, $item.BoxartPath) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if ($image) {
        try {
            $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.UriSource = [Uri]$image
            $bitmap.EndInit()
            $script:PreviewImage.Source = $bitmap
        } catch {
            $script:PreviewImage.Source = $null
        }
    } else {
        $script:PreviewImage.Source = $null
    }
}

function Update-BottomProgress {
    param([object]$Progress)
    try {
        if ($Progress.PSObject.Properties['Operation']) { $script:CurrentProgress.Operation = $Progress.Operation }
        if ($Progress.PSObject.Properties['System']) { $script:CurrentProgress.System = [string]$Progress.System }
        if ($Progress.PSObject.Properties['Current']) { $script:CurrentProgress.Current = [string]$Progress.Current }
        foreach ($p in @('SystemsCompleted','SystemsTotal','GamesDiscovered','MetadataCount','MetacriticMatches','WarningsCount')) {
            if ($Progress.PSObject.Properties[$p]) { $script:CurrentProgress[$p] = [int]$Progress.$p }
        }
        $elapsed = ''
        if ($script:CurrentProgress.StartedAt) {
            $elapsed = ' | elapsed ' + ([TimeSpan]((Get-Date) - $script:CurrentProgress.StartedAt)).ToString('hh\:mm\:ss')
        }
        $script:BottomDetailText.Text = "op=$($script:CurrentProgress.Operation) | system=$($script:CurrentProgress.System) | file=$($script:CurrentProgress.Current) | systems $($script:CurrentProgress.SystemsCompleted)/$($script:CurrentProgress.SystemsTotal) | games $($script:CurrentProgress.GamesDiscovered) | metadata $($script:CurrentProgress.MetadataCount) | matches $($script:CurrentProgress.MetacriticMatches) | warnings $($script:CurrentProgress.WarningsCount)$elapsed"
        if ($Progress.PSObject.Properties['Percent']) {
            $pct = [Math]::Max(0, [Math]::Min(100, [double]$Progress.Percent))
            $script:BottomProgressBar.Value = $pct
            $script:ScanProgressBar.Value = $pct
        }
    } catch {
        Add-Log 'Bottom progress update failed.' -Level 'ERROR' -Exception $_
    }
}

function Update-ScanProgress {
    param($Progress)
    try {
        Update-BottomProgress $Progress
        if ($Progress.PSObject.Properties['System'] -and $Progress.System) {
            $script:ScanProgressText.Text = "$($Progress.System) $($Progress.Operation)"
        } elseif ($Progress.PSObject.Properties['Message']) {
            $script:ScanProgressText.Text = [string]$Progress.Message
        }
        if ($Progress.PSObject.Properties['FileCount']) {
            Set-Status "$($Progress.Operation): $($Progress.FileCount) files"
        }
        if ($Progress.PSObject.Properties['Items'] -and $Progress.Operation -eq 'system-complete') {
            $items = @($Progress.Items)
            Add-Log "System scan complete: $($Progress.System), items=$($items.Count), roms=$($Progress.RomCount), metadata=$($Progress.MetadataCount), matches=$($Progress.MetacriticMatches), warnings=$($Progress.WarningsCount), seconds=$($Progress.ElapsedSeconds)"
            Add-LibraryItems -Items $items -ReplaceSystem -System $Progress.System
        }
    } catch {
        Add-Log 'Update-ScanProgress failed.' -Level 'ERROR' -Exception $_
    }
}

function Finish-Scan {
    try {
        $output = @($script:ScanPowerShell.EndInvoke($script:ScanHandle))
        $result = $output | Select-Object -Last 1
        if ($result) {
            $script:LastScanResult = $result
            if (-not $script:ScanKeepExisting) {
                Set-LibraryItems -Items @($result.Items)
            }
            $cacheResult = [pscustomobject]@{
                StartedAt = $result.StartedAt
                CompletedAt = $result.CompletedAt
                Items = @(ConvertTo-UiList $script:LibraryItems)
                Warnings = @($result.Warnings)
                Systems = @(ConvertTo-UiList $script:LibraryItems | Select-Object -ExpandProperty System -Unique)
                RatingRecordCount = $result.RatingRecordCount
            }
            $cacheInfo = Save-RomCuratorLibraryCache -ScanResult $cacheResult -Settings $script:Settings
            Add-Log "Scan complete: $($script:LibraryItems.Count) rows, $($result.Warnings.Count) warnings, $($result.RatingRecordCount) ratings."
            Add-Log "Library cache saved: $($cacheInfo.Path), items=$($cacheInfo.ItemCount), seconds=$($cacheInfo.DurationSeconds)"
            Update-CacheStatusText
            foreach ($warning in @($result.Warnings | Select-Object -First 200)) { Add-Log "[$($warning.Severity)] $($warning.Area) $($warning.System) $($warning.Message)" }
            $script:BottomProgressBar.Value = 100
            $script:BottomDetailText.Text = "Scan complete | games $($script:LibraryItems.Count) | warnings $($result.Warnings.Count) | cache $($cacheInfo.Path)"
        }
    } catch {
        Add-Log 'Scan finish failed.' -Level 'ERROR' -Exception $_
        Show-Error "Scan failed: $($_.Exception.Message)"
    } finally {
        $script:ScanTimer.Stop()
        $script:ScanButton.IsEnabled = $true
        $script:QuickScanButton.IsEnabled = $true
        $script:CancelScanButton.IsEnabled = $false
        $script:ScanProgressBar.Value = 100
        if ($script:ScanPowerShell) { $script:ScanPowerShell.Dispose() }
        if ($script:ScanRunspace) { $script:ScanRunspace.Dispose() }
        $script:ScanPowerShell = $null
        $script:ScanRunspace = $null
        $script:ScanHandle = $null
        $script:ScanCts = $null
        $script:ScanKeepExisting = $false
    }
}

$script:ScanTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:ScanTimer.Add_Tick({
    if ($script:ScanQueue) {
        $progress = $null
        while ($script:ScanQueue.TryDequeue([ref]$progress)) { Update-ScanProgress $progress }
    }
    if ($script:ScanHandle -and $script:ScanHandle.IsCompleted) { Finish-Scan }
})

function Start-Scan {
    param([string[]]$SystemsToScan, [switch]$KeepExisting)
    Read-SettingsFromUi | Out-Null
    Initialize-RomCuratorMetacriticData -Settings $script:Settings | Out-Null
    Save-RomCuratorSettings -Settings $script:Settings | Out-Null
    if (-not (Test-ConfiguredPaths)) { return }
    $script:ScanKeepExisting = [bool]$KeepExisting
    if (-not $KeepExisting) {
        $script:LibraryItems.Clear()
        $script:VisibleItems = @()
        if ($script:LibraryGrid) { $script:LibraryGrid.ItemsSource = $script:VisibleItems }
        Refresh-SystemFilter
        Update-Summary
    }
    $script:ScanQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    $script:ScanCts = [System.Threading.CancellationTokenSource]::new()
    $script:CurrentProgress.StartedAt = Get-Date
    $script:CurrentProgress.Operation = 'scan-start'
    $script:CurrentProgress.System = ''
    $script:CurrentProgress.Current = ''
    $script:CurrentProgress.GamesDiscovered = $script:LibraryItems.Count
    $script:BottomProgressBar.Value = 0
    $script:ScanRunspace = [runspacefactory]::CreateRunspace()
    $script:ScanRunspace.ApartmentState = 'MTA'
    $script:ScanRunspace.Open()
    $script:ScanPowerShell = [powershell]::Create()
    $script:ScanPowerShell.Runspace = $script:ScanRunspace
    $settingsJson = $script:Settings | ConvertTo-Json -Depth 20
    $systemsJson = @($SystemsToScan) | ConvertTo-Json -Depth 5
    [void]$script:ScanPowerShell.AddScript({
        param($modulePath, $settingsJson, $systemsJson, $queue, $cts)
        Import-Module $modulePath -Force -DisableNameChecking
        $settings = $settingsJson | ConvertFrom-Json
        $systems = @()
        if ($systemsJson) { $systems = @($systemsJson | ConvertFrom-Json) }
        Invoke-RomCuratorLibraryScan -Settings $settings -SystemsToScan $systems -CancellationToken $cts.Token -ProgressCallback {
            param($p)
            $queue.Enqueue($p)
        }
    }).AddArgument($script:ModulePath).AddArgument($settingsJson).AddArgument($systemsJson).AddArgument($script:ScanQueue).AddArgument($script:ScanCts)
    $script:ScanButton.IsEnabled = $false
    $script:QuickScanButton.IsEnabled = $false
    $script:CancelScanButton.IsEnabled = $true
    $script:ScanProgressBar.Value = 0
    $script:ScanProgressText.Text = 'Starting'
    Add-Log "Starting library scan. Systems=$(if ($SystemsToScan) { $SystemsToScan -join ',' } else { 'all' })"
    $script:ScanHandle = $script:ScanPowerShell.BeginInvoke()
    $script:ScanTimer.Start()
}

function Load-CacheIntoUi {
    param([switch]$Quiet)
    Read-SettingsFromUi | Out-Null
    $started = Get-Date
    Add-Log 'Loading library cache.'
    Set-Status 'Loading cache'
    $script:BottomDetailText.Text = 'Loading library cache...'
    $cache = Load-RomCuratorLibraryCache -Settings $script:Settings
    $script:LastCache = $cache.Cache
    if ($cache.Loaded -and $cache.Valid) {
        Set-LibraryItems -Items @($cache.Items)
        Add-Log "Cache loaded: items=$($script:LibraryItems.Count), seconds=$($cache.DurationSeconds), path=$($cache.Path)"
        $script:BottomDetailText.Text = "Cache loaded | games $($script:LibraryItems.Count) | $($cache.Path)"
        $script:BottomProgressBar.Value = 100
        return $true
    }
    Add-Log "Cache not loaded: $($cache.Reason)" -Level 'WARN'
    $script:BottomDetailText.Text = $cache.Reason
    if (-not $Quiet) { [System.Windows.MessageBox]::Show($script:Window, $cache.Reason, 'Library cache', 'OK', 'Information') | Out-Null }
    return $false
}

function Finish-CacheLoad {
    try {
        $output = @($script:CachePowerShell.EndInvoke($script:CacheHandle))
        $cache = $output | Select-Object -Last 1
        if ($cache -and $cache.Loaded -and $cache.Valid) {
            $script:LastCache = $cache.Cache
            Set-LibraryItems -Items @($cache.Items)
            Add-Log "Cache auto-loaded: items=$($script:LibraryItems.Count), seconds=$($cache.DurationSeconds), path=$($cache.Path)"
            $script:BottomDetailText.Text = "Loaded from cache | games $($script:LibraryItems.Count) | $($cache.Path)"
            $script:BottomProgressBar.Value = 100
            Update-CacheStatusText
        } else {
            $reason = if ($cache) { $cache.Reason } else { 'Cache load returned no result' }
            Add-Log "Cache not auto-loaded: $reason" -Level 'WARN'
            $script:BottomDetailText.Text = $reason
            Update-CacheStatusText
            if (-not $script:CacheQuiet) { [System.Windows.MessageBox]::Show($script:Window, $reason, 'Library cache', 'OK', 'Information') | Out-Null }
        }
    } catch {
        Add-Log 'Background cache load failed.' -Level 'ERROR' -Exception $_
        $script:BottomDetailText.Text = 'Cache load failed. See log.'
        if (-not $script:CacheQuiet) { Show-Error "Cache load failed: $($_.Exception.Message)" }
    } finally {
        $script:CacheTimer.Stop()
        if ($script:CachePowerShell) { $script:CachePowerShell.Dispose() }
        if ($script:CacheRunspace) { $script:CacheRunspace.Dispose() }
        $script:CachePowerShell = $null
        $script:CacheRunspace = $null
        $script:CacheHandle = $null
    }
}

$script:CacheTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:CacheTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$script:CacheTimer.Add_Tick({
    if ($script:CacheHandle -and $script:CacheHandle.IsCompleted) { Finish-CacheLoad }
})

function Start-CacheLoadIntoUi {
    param([switch]$Quiet)
    if ($script:CacheHandle) { return }
    Read-SettingsFromUi | Out-Null
    $script:CacheQuiet = [bool]$Quiet
    $script:BottomDetailText.Text = 'Loading cached library...'
    $script:BottomProgressBar.Value = 8
    Add-Log 'Starting background cache load.'
    $script:CacheRunspace = [runspacefactory]::CreateRunspace()
    $script:CacheRunspace.ApartmentState = 'MTA'
    $script:CacheRunspace.Open()
    $script:CachePowerShell = [powershell]::Create()
    $script:CachePowerShell.Runspace = $script:CacheRunspace
    $settingsJson = $script:Settings | ConvertTo-Json -Depth 20
    [void]$script:CachePowerShell.AddScript({
        param($modulePath, $settingsJson)
        Import-Module $modulePath -Force -DisableNameChecking
        $settings = $settingsJson | ConvertFrom-Json
        Load-RomCuratorLibraryCache -Settings $settings
    }).AddArgument($script:ModulePath).AddArgument($settingsJson)
    $script:CacheHandle = $script:CachePowerShell.BeginInvoke()
    $script:CacheTimer.Start()
}

function Delete-LibraryCacheFromUi {
    try {
        $removed = Remove-RomCuratorLibraryCache
        if ($removed) { Add-Log 'Library cache deleted.'; Set-Status 'Cache deleted' }
        else { Add-Log 'Delete cache requested but no cache file existed.'; Set-Status 'No cache found' }
        Update-CacheStatusText
    } catch {
        Add-Log 'Delete cache failed.' -Level 'ERROR' -Exception $_
        Show-Error $_.Exception.Message
    }
}

function Refresh-ChangedSystemsFromUi {
    Read-SettingsFromUi | Out-Null
    $cache = Load-RomCuratorLibraryCache -Settings $script:Settings -SkipValidation
    if (-not $cache.Loaded) {
        Add-Log 'Refresh changed systems requested, but no cache exists. Starting full scan.' -Level 'WARN'
        Start-Scan
        return
    }
    Set-LibraryItems -Items @($cache.Items)
    $script:LastCache = $cache.Cache
    $changed = @(Get-RomCuratorChangedSystems -Cache $cache.Cache -Settings $script:Settings)
    if ($changed.Count -eq 0) {
        Add-Log 'Refresh changed systems: no changed systems detected.'
        Set-Status 'No changed systems detected'
        return
    }
    Add-Log "Refreshing changed systems: $($changed -join ', ')"
    Start-Scan -SystemsToScan $changed -KeepExisting
}

function Finish-QuickDiscovery {
    try {
        $output = @($script:DiscoveryPowerShell.EndInvoke($script:DiscoveryHandle))
        $result = $output | Select-Object -Last 1
        $discovery = @()
        if ($result -and $result.PSObject.Properties['Systems']) { $discovery = @($result.Systems) } else { $discovery = @($result) }
        $script:DiscoveryItems = @($discovery)
        Update-SystemRows -DiscoveryRows $script:DiscoveryItems
        $matched = @($script:DiscoveryItems | Where-Object { $_.HasGamelist -and $_.HasRomFolder }).Count
        $warnings = @($script:DiscoveryItems | Where-Object { $_.WarningsText }).Count
        $script:BottomProgressBar.Value = 100
        $script:BottomDetailText.Text = "Discovery complete | systems $($script:DiscoveryItems.Count) | matched $matched | warnings $warnings"
        Add-Log "Quick discovery complete: systems=$($script:DiscoveryItems.Count), matched=$matched, warnings=$warnings, cache=$($result.CachePath)"
        foreach ($entry in @($script:DiscoveryItems)) {
            Add-Log "Discovery: system=$($entry.System) gamelist=$($entry.HasGamelist) roms=$($entry.HasRomFolder) media=$($entry.HasMediaFolder) approx=$($entry.EstimatedFileCount) notes=$($entry.WarningsText)"
        }
    } catch {
        Add-Log 'Quick discovery failed.' -Level 'ERROR' -Exception $_
        Show-Error "System discovery failed: $($_.Exception.Message)"
    } finally {
        $script:DiscoveryTimer.Stop()
        $script:QuickScanButton.IsEnabled = $true
        if ($script:DiscoveryPowerShell) { $script:DiscoveryPowerShell.Dispose() }
        if ($script:DiscoveryRunspace) { $script:DiscoveryRunspace.Dispose() }
        $script:DiscoveryPowerShell = $null
        $script:DiscoveryRunspace = $null
        $script:DiscoveryHandle = $null
    }
}

$script:DiscoveryTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:DiscoveryTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$script:DiscoveryTimer.Add_Tick({
    if ($script:DiscoveryHandle -and $script:DiscoveryHandle.IsCompleted) { Finish-QuickDiscovery }
})

function Start-QuickDiscovery {
    if ($script:DiscoveryHandle) { return }
    Read-SettingsFromUi | Out-Null
    Save-RomCuratorSettings -Settings $script:Settings | Out-Null
    $script:BottomDetailText.Text = 'Discovering systems...'
    $script:BottomProgressBar.Value = 15
    $script:QuickScanButton.IsEnabled = $false
    Add-Log 'Starting quick system discovery.'
    $script:DiscoveryRunspace = [runspacefactory]::CreateRunspace()
    $script:DiscoveryRunspace.ApartmentState = 'MTA'
    $script:DiscoveryRunspace.Open()
    $script:DiscoveryPowerShell = [powershell]::Create()
    $script:DiscoveryPowerShell.Runspace = $script:DiscoveryRunspace
    $settingsJson = $script:Settings | ConvertTo-Json -Depth 20
    [void]$script:DiscoveryPowerShell.AddScript({
        param($modulePath, $settingsJson)
        Import-Module $modulePath -Force -DisableNameChecking
        $settings = $settingsJson | ConvertFrom-Json
        $systems = @(Get-RomCuratorSystemDiscovery -Settings $settings)
        $cachePath = Save-RomCuratorDiscoveryCache -Discovery $systems -Settings $settings
        [pscustomobject]@{ Systems=$systems; CachePath=$cachePath }
    }).AddArgument($script:ModulePath).AddArgument($settingsJson)
    $script:DiscoveryHandle = $script:DiscoveryPowerShell.BeginInvoke()
    $script:DiscoveryTimer.Start()
}

function Get-DiscoverySystemsForScope {
    $scope = Get-ComboContent $script:ScanScopeCombo
    $items = if ($script:SystemRows -and @($script:SystemRows).Count -gt 0) { @($script:SystemRows) } else { @($script:DiscoveryItems) }
    if ($items.Count -eq 0) { return @() }
    if ($scope -eq 'Scan entire ROM directory') {
        return @($items | Where-Object { ($_.HasRomFolder -and [int]$_.EstimatedFileCount -gt 0) -or $_.CopyableGames -gt 0 } | Select-Object -ExpandProperty System)
    }
    if ($scope -eq 'Scan selected systems only') {
        return @($items | Where-Object { $_.Selected -and (($_.HasRomFolder -and [int]$_.EstimatedFileCount -gt 0) -or $_.CopyableGames -gt 0) } | Select-Object -ExpandProperty System)
    }
    return @($items | Where-Object { (($_.HasGamelist -and $_.HasRomFolder -and [int]$_.EstimatedFileCount -gt 0) -or $_.CopyableGames -gt 0) } | Select-Object -ExpandProperty System)
}

function Open-FolderSafe {
    param([string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { Ensure-RomCuratorDirectory $Path | Out-Null }
        Start-Process explorer.exe -ArgumentList "`"$Path`""
    } catch {
        Add-Log "Open folder failed: $Path" -Level 'ERROR' -Exception $_
        Show-Error $_.Exception.Message
    }
}

function Start-MetacriticUpdate {
    $sourceScript = Join-Path $script:Root 'tools\Build-Metacritic-Critic-Scores.ps1'
    if (-not (Test-Path -LiteralPath $sourceScript)) {
        $sourceScript = 'C:\Users\Rollza\Downloads\metacritic_scores_powershell_runner_v5\Build-Metacritic-Critic-Scores.ps1'
    }
    if (-not (Test-Path -LiteralPath $sourceScript)) {
        Show-Error "Metacritic updater script not found:`n$sourceScript"
        return
    }
    $target = Get-RomCuratorCachedRatingPath
    $output = Join-Path (Get-RomCuratorCacheFolder) ("metacritic_update_{0}.jsonl" -f (Get-Date -Format yyyyMMdd_HHmmss))
    Add-Log "Starting Metacritic update using $sourceScript -> $output"
    $script:BottomDetailText.Text = 'Updating Metacritic ratings...'
    $script:BottomProgressBar.Value = 0
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = (Get-Process -Id $PID).Path
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$sourceScript`" -OutputPath `"$output`" -StartPage 0 -MaxPages 591 -DelaySeconds 3 -TimeoutSeconds 30"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($psi)
        while (-not $process.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 250
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        if ($stdout) { Add-Log "Metacritic updater output:`n$stdout" }
        if ($stderr) { Add-Log "Metacritic updater error output:`n$stderr" -Level 'WARN' }
        if ($process.ExitCode -ne 0) { throw "Updater exited with code $($process.ExitCode)" }
        $warnings = [System.Collections.Generic.List[object]]::new()
        $records = @(Import-RomCuratorMetacriticJsonl -Path $output -Warnings $warnings)
        if ($records.Count -lt 100) { throw "Updated ratings file looked too small: $($records.Count) records" }
        if (Test-Path -LiteralPath $target) {
            Copy-Item -LiteralPath $target -Destination "$target.backup.$(Get-Date -Format yyyyMMddHHmmss)" -Force
        }
        Move-Item -LiteralPath $output -Destination $target -Force
        $script:Settings.RatingFilePath = $target
        Save-RomCuratorSettings -Settings $script:Settings | Out-Null
        $info = Update-MetacriticInfo
        Add-Log "Metacritic update complete: $($info.Version)"
        $script:BottomDetailText.Text = "Metacritic updated | $($info.Version)"
        $script:BottomProgressBar.Value = 100
    } catch {
        Add-Log 'Metacritic update failed; previous database left in place.' -Level 'ERROR' -Exception $_
        Show-Error "Metacritic update failed. Existing ratings were kept.`n`n$($_.Exception.Message)"
    }
}

function Get-FullSelectedSystemsFromUi {
    Sync-SystemStateFromRows
    return @($script:FullSystemSelection)
}

function New-ExportPlanFromUi {
    param([switch]$FullSystemsOnly)
    Read-SettingsFromUi | Out-Null
    Save-RomCuratorSettings -Settings $script:Settings | Out-Null
    if ([string]::IsNullOrWhiteSpace($script:Settings.ExportDestination)) { throw 'Choose an export destination first.' }
    $includeMedia = [bool]$script:IncludeMediaCheck.IsChecked
    $includeGamelists = [bool]$script:IncludeGamelistCheck.IsChecked
    $fullSystems = @(Get-FullSelectedSystemsFromUi)
    Get-RomCuratorExportPlan -Items @(ConvertTo-UiList $script:LibraryItems) -Settings $script:Settings -FullSystems $fullSystems -IgnoreItemSelection:$FullSystemsOnly -IncludeMedia:$includeMedia -IncludeGamelists:$includeGamelists
}

function Show-ExportPlan {
    param($Plan)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Destination: $($Plan.Destination)")
    $lines.Add("Profile: $($Plan.Profile.Name)")
    $lines.Add("Mode: $($Plan.PlanMode)")
    if ($Plan.PSObject.Properties['FullSystems'] -and @($Plan.FullSystems).Count -gt 0) { $lines.Add("Full systems: $(@($Plan.FullSystems) -join ', ')") }
    $lines.Add("Selected games: $($Plan.SelectedCount)")
    $lines.Add("Copy operations: $($Plan.CopyItems.Count)")
    $lines.Add("Estimated total: $($Plan.TotalGB) GB")
    $lines.Add('')
    $lines.Add('Per system:')
    foreach ($row in $Plan.PerSystem) { $lines.Add("  $($row.System): $($row.Count) games, $($row.SizeGB) GB") }
    $lines.Add('')
    $lines.Add('First copy operations:')
    foreach ($copy in @($Plan.CopyItems | Select-Object -First 80)) { $lines.Add("  [$($copy.Kind)] $($copy.Source) -> $($copy.Destination)") }
    if ($Plan.CopyItems.Count -gt 80) { $lines.Add("  ... $($Plan.CopyItems.Count - 80) more") }
    $script:ExportPlanBox.Text = ($lines -join [Environment]::NewLine)
}

function Update-ExportProgress {
    param($Progress)
    if ($Progress.Operation -eq 'export') {
        $pct = if ($Progress.TotalBytes -gt 0) { [Math]::Min(100, ($Progress.BytesCopied * 100.0 / $Progress.TotalBytes)) } else { 0 }
        $script:ExportProgressBar.Value = $pct
        $script:BottomProgressBar.Value = $pct
        $mbs = if ($Progress.SpeedBytesPerSecond) { [Math]::Round($Progress.SpeedBytesPerSecond / 1MB, 2) } else { 0 }
        $script:ExportProgressText.Text = "$($Progress.Index)/$($Progress.Count) | $([Math]::Round($Progress.BytesCopied / 1GB, 3)) / $([Math]::Round($Progress.TotalBytes / 1GB, 3)) GB | $mbs MB/s | ETA $($Progress.Remaining)"
        $script:BottomDetailText.Text = "export | $($Progress.Index)/$($Progress.Count) | $([Math]::Round($Progress.BytesCopied / 1GB, 3))/$([Math]::Round($Progress.TotalBytes / 1GB, 3)) GB | $mbs MB/s"
    } elseif ($Progress.Operation -eq 'copy-file') {
        Set-Status "Copying $($Progress.Current)"
    } elseif ($Progress.Operation -eq 'export-complete') {
        $script:ExportProgressBar.Value = 100
        $script:BottomProgressBar.Value = 100
        $script:ExportProgressText.Text = 'Export complete'
        $script:BottomDetailText.Text = 'Export complete'
    }
}

function Finish-Export {
    try {
        $output = @($script:ExportPowerShell.EndInvoke($script:ExportHandle))
        $result = $output | Select-Object -Last 1
        if ($result) {
            Add-Log "Export finished: $($result.Results.Count) operations. Manifest: $($result.Manifest.Json)"
            $script:ExportPlanBox.AppendText([Environment]::NewLine + [Environment]::NewLine + "Manifest: $($result.Manifest.Json)")
        }
    } catch {
        Show-Error "Export failed: $($_.Exception.Message)"
    } finally {
        $script:ExportTimer.Stop()
        $script:RunExportButton.IsEnabled = $true
        $script:PreviewExportButton.IsEnabled = $true
        $script:CancelExportButton.IsEnabled = $false
        if ($script:ExportPowerShell) { $script:ExportPowerShell.Dispose() }
        if ($script:ExportRunspace) { $script:ExportRunspace.Dispose() }
        $script:ExportPowerShell = $null
        $script:ExportRunspace = $null
        $script:ExportHandle = $null
        $script:ExportCts = $null
    }
}

$script:ExportTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:ExportTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:ExportTimer.Add_Tick({
    if ($script:ExportQueue) {
        $progress = $null
        while ($script:ExportQueue.TryDequeue([ref]$progress)) { Update-ExportProgress $progress }
    }
    if ($script:ExportHandle -and $script:ExportHandle.IsCompleted) { Finish-Export }
})

function Start-Export {
    param([switch]$DryRun, [switch]$FullSystemsOnly)
    try {
        $planStarted = Get-Date
        $plan = New-ExportPlanFromUi -FullSystemsOnly:$FullSystemsOnly
        $script:CurrentExportPlan = $plan
        Show-ExportPlan $plan
        Add-Log "Export planning completed: mode=$($plan.PlanMode), systems=$(@($plan.FullSystems) -join ','), copyItems=$($plan.CopyItems.Count), ms=$([Math]::Round(((Get-Date)-$planStarted).TotalMilliseconds,1))"
        if ($plan.SelectedCount -eq 0) { Show-Error 'No games are selected.'; return }
        if (-not (Test-Path -LiteralPath $plan.Destination)) {
            $create = [System.Windows.MessageBox]::Show($script:Window, "Export destination does not exist. Create it?`n$($plan.Destination)", 'Create destination', 'OKCancel', 'Question')
            if ($create -ne [System.Windows.MessageBoxResult]::OK) { return }
            Ensure-RomCuratorDirectory $plan.Destination | Out-Null
        }
        try {
            $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($plan.Destination))
            $drive = [IO.DriveInfo]::new($root)
            if ($drive.AvailableFreeSpace -lt [int64]$plan.TotalBytes) {
                $freeGb = [Math]::Round($drive.AvailableFreeSpace / 1GB, 2)
                $needGb = [Math]::Round($plan.TotalBytes / 1GB, 2)
                $continue = [System.Windows.MessageBox]::Show($script:Window, "Destination may not have enough free space.`nFree: $freeGb GB`nNeeded: $needGb GB`nContinue anyway?", 'Low disk space', 'OKCancel', 'Warning')
                if ($continue -ne [System.Windows.MessageBoxResult]::OK) { return }
            }
        } catch { Add-Log 'Free-space check failed.' -Level 'WARN' -Exception $_ }
        if (-not $DryRun) {
            $msg = "Copy $($plan.SelectedCount) games and $($plan.TotalGB) GB to:`n$($plan.Destination)`n`nSource files will not be modified."
            $confirm = [System.Windows.MessageBox]::Show($script:Window, $msg, 'Confirm export', 'OKCancel', 'Warning')
            if ($confirm -ne [System.Windows.MessageBoxResult]::OK) { return }
        }
        $script:ExportQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
        $script:ExportCts = [System.Threading.CancellationTokenSource]::new()
        $script:ExportRunspace = [runspacefactory]::CreateRunspace()
        $script:ExportRunspace.ApartmentState = 'MTA'
        $script:ExportRunspace.Open()
        $script:ExportPowerShell = [powershell]::Create()
        $script:ExportPowerShell.Runspace = $script:ExportRunspace
        $planJson = $plan | ConvertTo-Json -Depth 30
        $itemsJson = @(ConvertTo-UiList $script:LibraryItems) | ConvertTo-Json -Depth 30
        $policy = [string]$script:Settings.OverwritePolicy
        [void]$script:ExportPowerShell.AddScript({
            param($modulePath, $planJson, $itemsJson, $policy, $dryRun, $queue, $cts)
            Import-Module $modulePath -Force -DisableNameChecking
            $plan = $planJson | ConvertFrom-Json
            $items = @($itemsJson | ConvertFrom-Json)
            Invoke-RomCuratorExport -Plan $plan -AllItems $items -OverwritePolicy $policy -DryRun:$dryRun -CancellationToken $cts.Token -ProgressCallback {
                param($p)
                $queue.Enqueue($p)
            }
        }).AddArgument($script:ModulePath).AddArgument($planJson).AddArgument($itemsJson).AddArgument($policy).AddArgument([bool]$DryRun).AddArgument($script:ExportQueue).AddArgument($script:ExportCts)
        $script:RunExportButton.IsEnabled = $false
        $script:PreviewExportButton.IsEnabled = $false
        $script:CancelExportButton.IsEnabled = $true
        $script:ExportProgressBar.Value = 0
        $script:ExportProgressText.Text = if ($DryRun) { 'Dry run running' } else { 'Export running' }
        Add-Log $(if ($DryRun) { "Starting export dry run. mode=$($plan.PlanMode)" } else { "Starting export copy. mode=$($plan.PlanMode)" })
        $script:ExportHandle = $script:ExportPowerShell.BeginInvoke()
        $script:ExportTimer.Start()
    } catch {
        Show-Error $_.Exception.Message
    }
}

function Open-ContainingFolder {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $target = if (Test-Path -LiteralPath $Path -PathType Leaf) { "/select,`"$Path`"" } else { "`"$Path`"" }
    Start-Process explorer.exe -ArgumentList $target
}

function Edit-SelectedRating {
    $item = $script:LibraryGrid.SelectedItem
    if (-not $item) { return }
    $default = "$($item.CriticScore)|$($item.RatingTitleMatched)|$($item.MatchConfidence)"
    $input = [Microsoft.VisualBasic.Interaction]::InputBox('Enter score|matched title|confidence', 'Edit Metacritic match', $default)
    if ([string]::IsNullOrWhiteSpace($input)) { return }
    $parts = $input -split '\|', 3
    if ($parts.Count -ge 1) {
        $score = 0
        if ([int]::TryParse($parts[0].Trim(), [ref]$score)) { $item.CriticScore = $score }
    }
    if ($parts.Count -ge 2) { $item.RatingTitleMatched = $parts[1].Trim() }
    if ($parts.Count -ge 3) {
        $conf = 0.0
        if ([double]::TryParse($parts[2].Trim(), [ref]$conf)) { $item.MatchConfidence = $conf }
    }
    $item.RatingMatchMethod = 'manual'
    Show-SelectedPreview
    Apply-Filters
}

function Set-SelectedImage {
    $item = $script:LibraryGrid.SelectedItem
    if (-not $item) { return }
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Filter = 'Images|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All files|*.*'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $item.ImagePath = $dialog.FileName
        $item.HasImage = $true
        try { $item.MediaSize += (Get-Item -LiteralPath $dialog.FileName).Length } catch {}
        Show-SelectedPreview
        Apply-Filters
    }
}

function Set-VisibleSelection([scriptblock]$Setter) {
    foreach ($item in $script:VisibleItems) { & $Setter $item }
    $script:LibraryGrid.Items.Refresh()
    Update-Summary
    Update-SystemRows
}

Load-SettingsToUi
Initialize-UiDropdowns
Update-MetacriticInfo | Out-Null
Update-CacheStatusText
$script:BuildInfoText.Text = "$script:AppName $script:AppVersion | PowerShell $($PSVersionTable.PSVersion) | $([Environment]::OSVersion.VersionString)"
Add-Log "$script:AppName loaded. Version=$script:AppVersion OS=$([Environment]::OSVersion.VersionString) Runtime=$($PSVersionTable.PSVersion) Log=$script:LogPath"
Add-Log "Configured paths: gamelists=$($script:Settings.GamelistsRoot); roms=$($script:Settings.RomsRoot); media=$($script:Settings.MediaRoot); rating=$($script:Settings.RatingFilePath)"
Reorder-MainTabs
Apply-AppTheme -DarkMode (Get-DarkModeEnabled)
Start-CacheLoadIntoUi -Quiet

$script:BrowseGamelistsButton.Add_Click({ $p = Browse-Folder $script:GamelistsRootBox.Text; if ($p) { $script:GamelistsRootBox.Text = $p } })
$script:BrowseRomsButton.Add_Click({ $p = Browse-Folder $script:RomsRootBox.Text; if ($p) { $script:RomsRootBox.Text = $p } })
$script:BrowseMediaButton.Add_Click({ $p = Browse-Folder $script:MediaRootBox.Text; if ($p) { $script:MediaRootBox.Text = $p } })
$script:BrowseExportButton.Add_Click({ $p = Browse-Folder $script:ExportDestinationBox.Text; if ($p) { $script:ExportDestinationBox.Text = $p } })
$script:ValidatePathsButton.Add_Click({ Test-ConfiguredPaths | Out-Null })
$script:SaveSettingsButton.Add_Click({ Read-SettingsFromUi | Out-Null; Initialize-RomCuratorMetacriticData -Settings $script:Settings | Out-Null; $path = Save-RomCuratorSettings -Settings $script:Settings; Update-MetacriticInfo | Out-Null; Apply-AppTheme -DarkMode $script:Settings.DarkMode; Add-Log "Path/theme settings saved to $path"; Set-Status 'Settings saved' })
$script:DarkModeCheck.Add_Checked({ try { Read-SettingsFromUi | Out-Null; $script:Settings.DarkMode = $true; $script:Settings.Theme = 'Dark'; Apply-AppTheme -DarkMode $true; Save-RomCuratorSettings -Settings $script:Settings | Out-Null; Add-Log 'Dark mode enabled.' } catch { Add-Log 'Dark mode toggle failed.' -Level 'ERROR' -Exception $_ } })
$script:DarkModeCheck.Add_Unchecked({ try { Read-SettingsFromUi | Out-Null; $script:Settings.DarkMode = $false; $script:Settings.Theme = 'Light'; Apply-AppTheme -DarkMode $false; Save-RomCuratorSettings -Settings $script:Settings | Out-Null; Add-Log 'Dark mode disabled.' } catch { Add-Log 'Dark mode toggle failed.' -Level 'ERROR' -Exception $_ } })
$script:ResetSettingsButton.Add_Click({ $script:Settings = New-RomCuratorDefaultSettings; Load-SettingsToUi; Apply-AppTheme -DarkMode $script:Settings.DarkMode; Save-RomCuratorSettings -Settings $script:Settings | Out-Null; Add-Log 'App settings reset to defaults.' })
$script:ResetPathSettingsButton.Add_Click({ $defaults = New-RomCuratorDefaultSettings; $script:GamelistsRootBox.Text = $defaults.GamelistsRoot; $script:RomsRootBox.Text = $defaults.RomsRoot; $script:MediaRootBox.Text = $defaults.MediaRoot; $script:ExportDestinationBox.Text = $defaults.ExportDestination; Set-ComboByContent $script:MediaModeCombo $defaults.MediaMode; Set-ComboByContent $script:ExportProfileCombo $defaults.ExportProfile; Add-Log 'Path settings reset to defaults in UI.' })
$script:ExportConfigButton.Add_Click({
    $dialog = [System.Windows.Forms.SaveFileDialog]::new()
    $dialog.Filter = 'JSON config|*.json'
    $dialog.FileName = 'romcurator_config.json'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Read-SettingsFromUi | Out-Null; Export-RomCuratorConfig -Settings $script:Settings -Path $dialog.FileName; Add-Log "Config exported to $($dialog.FileName)" }
})
$script:LoadConfigButton.Add_Click({
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Filter = 'JSON config|*.json|All files|*.*'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $script:Settings = Import-RomCuratorConfig -Path $dialog.FileName; Load-SettingsToUi; Add-Log "Config loaded from $($dialog.FileName)" }
})

$script:LoadCacheButton.Add_Click({ Start-CacheLoadIntoUi })
$script:RefreshChangedButton.Add_Click({ Refresh-ChangedSystemsFromUi })
$script:ForceFullRescanButton.Add_Click({ Start-Scan })
$script:DeleteCacheButton.Add_Click({ Delete-LibraryCacheFromUi })
$script:OpenCacheFolderButton.Add_Click({ Open-FolderSafe (Get-RomCuratorCacheFolder) })
$script:OpenLogFolderButton.Add_Click({ Open-FolderSafe (Get-RomCuratorLogFolder) })
$script:ViewLatestLogButton.Add_Click({ Open-ContainingFolder $script:LogPath })
$script:OpenAppDataFolderButton.Add_Click({ Open-FolderSafe (Get-RomCuratorAppDataPath '') })
$script:UpdateMetacriticButton.Add_Click({ Start-MetacriticUpdate })
$script:RollbackMetacriticButton.Add_Click({ $path = Copy-RomCuratorBundledMetacriticData; $script:Settings.RatingFilePath = $path; Save-RomCuratorSettings -Settings $script:Settings | Out-Null; Update-MetacriticInfo | Out-Null; Add-Log "Restored bundled Metacritic ratings to $path" })

$script:QuickScanButton.Add_Click({ Start-QuickDiscovery })
$script:ScanButton.Add_Click({ Start-Scan })
$script:CancelScanButton.Add_Click({ if ($script:ScanCts) { $script:ScanCts.Cancel(); Add-Log 'Scan cancellation requested.' } })
$script:RunDiscoveredScanButton.Add_Click({
    $systems = @(Get-DiscoverySystemsForScope)
    Add-Log "Discovery scan scope selected: $(Get-ComboContent $script:ScanScopeCombo); systems=$($systems -join ',')"
    if ($systems.Count -eq 0) {
        [System.Windows.MessageBox]::Show($script:Window, 'No systems are selected for scanning.', 'Scan scope', 'OK', 'Information') | Out-Null
        return
    }
    Start-Scan -SystemsToScan $systems
})
$script:DiscoveryGrid.Add_CurrentCellChanged({ Update-SystemSelectionSummaries })
$script:ExcludedSystemsGrid.Add_CurrentCellChanged({ Update-SystemSelectionSummaries; Refresh-ExcludedSystemsGrid })
$script:ExcludedSystemsSearchBox.Add_TextChanged({ Refresh-ExcludedSystemsGrid })
$script:SelectAllSystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { if ($row.HasRomFolder -and [int]$row.EstimatedFileCount -gt 0) { $row.Selected = $true } }; Update-SystemSelectionSummaries; $script:DiscoveryGrid.Items.Refresh(); Add-Log 'All valid non-empty systems selected for scanning.' })
$script:DeselectAllSystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { $row.Selected = $false }; Update-SystemSelectionSummaries; $script:DiscoveryGrid.Items.Refresh(); Add-Log 'All systems deselected for scanning.' })
$script:SelectAllFullSystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { if ($row.HasRomFolder -and [int]$row.EstimatedFileCount -gt 0) { $row.FullSystemSelected = $true } }; Update-SystemSelectionSummaries; $script:DiscoveryGrid.Items.Refresh(); Add-Log 'All valid non-empty systems selected for full-system export.' })
$script:DeselectAllFullSystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { $row.FullSystemSelected = $false }; Update-SystemSelectionSummaries; $script:DiscoveryGrid.Items.Refresh(); Add-Log 'All systems deselected for full-system export.' })
$script:ExportFullSystemsButton.Add_Click({ Update-SystemSelectionSummaries; Add-Log "Full-system export requested: $(@($script:FullSystemSelection) -join ',')"; Start-Export -FullSystemsOnly })
$script:ExcludeAllSystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { $row.ExcludedFromAutoSelect = $true }; Update-SystemSelectionSummaries; Refresh-ExcludedSystemsGrid; Add-Log 'All systems excluded from auto-select.' })
$script:IncludeAllSystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { $row.ExcludedFromAutoSelect = $false }; Update-SystemSelectionSummaries; Refresh-ExcludedSystemsGrid; Add-Log 'All systems included in auto-select.' })
$script:ExcludeEmptySystemsButton.Add_Click({ foreach ($row in @($script:SystemRows)) { if ([int]$row.CopyableGames -eq 0) { $row.ExcludedFromAutoSelect = $true } }; Update-SystemSelectionSummaries; Refresh-ExcludedSystemsGrid; Add-Log 'Empty systems excluded from auto-select.' })

foreach ($box in @($script:SearchBox,$script:MinScoreBox,$script:MaxScoreBox,$script:GenreFilterBox,$script:PlayersFilterBox)) { if ($box) { $box.Add_TextChanged({ Schedule-ApplyFilters }) } }
foreach ($combo in @($script:GenreFilterCombo,$script:PlayersFilterCombo,$script:ScorePresetCombo,$script:FavoritesFilterCombo,$script:MediaFilterCombo)) { $combo.Add_SelectionChanged({ Schedule-ApplyFilters }) }
foreach ($check in @($script:FavoritesOnlyCheck,$script:HasMediaCheck,$script:MissingMediaCheck,$script:HasScoreCheck,$script:SelectedOnlyCheck,$script:UnmatchedOnlyCheck,$script:IssuesOnlyCheck,$script:DuplicatesOnlyCheck)) { if ($check) { $check.Add_Checked({ Schedule-ApplyFilters }); $check.Add_Unchecked({ Schedule-ApplyFilters }) } }
$script:SystemFilterCombo.Add_SelectionChanged({
    if ($script:SystemFilterChanging) { return }
    try {
        Add-Log "System selected: $(Get-ComboContent $script:SystemFilterCombo)"
        Schedule-ApplyFilters
    } catch {
        Add-Log 'System selection handling failed.' -Level 'ERROR' -Exception $_
    }
})
$script:ClearFiltersButton.Add_Click({
    $script:SearchBox.Text = ''; $script:MinScoreBox.Text = ''; $script:MaxScoreBox.Text = ''; $script:GenreFilterBox.Text = ''; $script:PlayersFilterBox.Text = ''
    $script:FavoritesOnlyCheck.IsChecked = $false; if ($script:HasMediaCheck) { $script:HasMediaCheck.IsChecked = $false }; $script:MissingMediaCheck.IsChecked = $false; if ($script:HasScoreCheck) { $script:HasScoreCheck.IsChecked = $false }; $script:SelectedOnlyCheck.IsChecked = $false; $script:UnmatchedOnlyCheck.IsChecked = $false; $script:IssuesOnlyCheck.IsChecked = $false; if ($script:DuplicatesOnlyCheck) { $script:DuplicatesOnlyCheck.IsChecked = $false }
    if ($script:GenreFilterCombo.Items.Count -gt 0) { $script:GenreFilterCombo.SelectedIndex = 0 }
    if ($script:PlayersFilterCombo.Items.Count -gt 0) { $script:PlayersFilterCombo.SelectedIndex = 0 }
    if ($script:ScorePresetCombo.Items.Count -gt 0) { $script:ScorePresetCombo.SelectedIndex = 0 }
    if ($script:FavoritesFilterCombo.Items.Count -gt 0) { $script:FavoritesFilterCombo.SelectedIndex = 0 }
    if ($script:MediaFilterCombo.Items.Count -gt 0) { $script:MediaFilterCombo.SelectedIndex = 0 }
    if ($script:SystemFilterCombo.Items.Count -gt 0) { $script:SystemFilterCombo.SelectedIndex = 0 }
    Apply-Filters
})
$script:LibraryGrid.Add_SelectionChanged({ Show-SelectedPreview })
$script:LibraryGrid.Add_CurrentCellChanged({ Update-Summary })

$script:SelectVisibleButton.Add_Click({ Set-VisibleSelection { param($i) $i.Selected = $true } })
$script:DeselectVisibleButton.Add_Click({ Set-VisibleSelection { param($i) $i.Selected = $false } })
$script:InvertVisibleButton.Add_Click({ Set-VisibleSelection { param($i) $i.Selected = -not [bool]$i.Selected } })
$script:SelectSystemButton.Add_Click({
    $system = Get-ComboContent $script:SystemFilterCombo
    if ($system -and $system -ne 'All') { foreach ($item in ConvertTo-UiList $script:LibraryItems | Where-Object { $_.System -eq $system }) { $item.Selected = $true } }
    $script:LibraryGrid.Items.Refresh(); Update-Summary; Update-SystemRows; Add-Log "Selected system ignoring filters: $system"
})
$script:ClearSelectionButton.Add_Click({ foreach ($item in ConvertTo-UiList $script:LibraryItems) { $item.Selected = $false }; $script:LibraryGrid.Items.Refresh(); Update-Summary; Update-SystemRows; Add-Log 'Selection cleared.' })
$script:SaveSelectionButton.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Preset name', 'Save selection preset', 'Selection')
    if ($name) {
        Read-SettingsFromUi | Out-Null
        $result = Save-RomCuratorUserPreset -Items @(ConvertTo-UiList $script:LibraryItems) -Name $name -Settings $script:Settings -AppVersion $script:AppVersion
        Add-Log "User preset saved to $($result.Path), selected=$($result.SelectedCount)"
        Set-Status "User preset saved"
    }
})
$script:SaveCommunityPresetButton.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Shareable preset name', 'Save community preset', 'Community Selection')
    if ($name) {
        $result = Save-RomCuratorCommunityPreset -Items @(ConvertTo-UiList $script:LibraryItems) -Name $name -AppVersion $script:AppVersion
        Add-Log "Community preset saved to $($result.Path), selected=$($result.SelectedCount), sanitized=$($result.SanitizedCount)"
        Set-Status "Community preset saved"
    }
})
$script:LoadSelectionButton.Add_Click({
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Filter = 'Selection presets|*.json|All files|*.*'
    $presetDir = Get-RomCuratorAppDataPath 'selection-presets'
    if (Test-Path -LiteralPath $presetDir) { $dialog.InitialDirectory = $presetDir }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $summary = Load-RomCuratorSelectionPreset -Items @(ConvertTo-UiList $script:LibraryItems) -Path $dialog.FileName
        Apply-Filters
        $match = if ($summary.PSObject.Properties['PresetMatches']) { $summary.PresetMatches } else { $null }
        if ($match) {
            Add-Log "Selection preset loaded from $($dialog.FileName): matched=$($match.Matched), missing=$($match.Missing), ambiguous=$($match.Ambiguous)"
            Set-Status "Preset loaded: $($match.Matched) matched, $($match.Missing) missing, $($match.Ambiguous) ambiguous"
        } else {
            Add-Log "Selection preset loaded from $($dialog.FileName)"
        }
    }
})

$script:OpenRomLocationButton.Add_Click({ $item = $script:LibraryGrid.SelectedItem; if ($item) { Open-ContainingFolder $item.RomPath } })
$script:OpenMediaLocationButton.Add_Click({ $item = $script:LibraryGrid.SelectedItem; if ($item) { $p = @($item.ImagePath,$item.VideoPath,$item.ThumbnailPath) | Where-Object { $_ } | Select-Object -First 1; Open-ContainingFolder $p } })
$script:SetImageButton.Add_Click({ Set-SelectedImage })
$script:EditRatingButton.Add_Click({ Edit-SelectedRating })

$script:RunAutoSelectButton.Add_Click({
    try {
        $summary = Select-RomCuratorByCriteria -Items @(ConvertTo-UiList $script:LibraryItems) `
            -TopNOverall (Get-IntBox $script:TopNOverallBox 0) `
            -TopNPerSystem (Get-IntBox $script:TopNPerSystemBox 0) `
            -MinimumScore (Get-IntBox $script:AutoMinScoreBox 0) `
            -MaxTotalGB (Get-DoubleBox $script:MaxTotalGbBox 0) `
            -IncludeSystems (Split-ListText $script:IncludeSystemsBox.Text) `
            -ExcludeSystems (Split-ListText $script:ExcludeSystemsBox.Text) `
            -IncludeGenres (Split-ListText $script:IncludeGenresBox.Text) `
            -ExcludeGenres (Split-ListText $script:ExcludeGenresBox.Text) `
            -PreferFavorites:([bool]$script:PreferFavoritesCheck.IsChecked) `
            -PreferMultiplayer:([bool]$script:PreferMultiplayerCheck.IsChecked) `
            -ExcludeHidden:([bool]$script:ExcludeHiddenCheck.IsChecked) `
            -ExcludeKidGame:([bool]$script:ExcludeKidGameCheck.IsChecked) `
            -ExcludeUnmatched:([bool]$script:ExcludeUnmatchedCheck.IsChecked) `
            -FillMode (Get-ComboContent $script:FillModeCombo)
        $script:AutoSelectSummaryBox.Text = @(
            "Selected: $($summary.SelectedCount)"
            "ROM size: $($summary.RomSizeGB) GB"
            "Media size: $($summary.MediaSizeGB) GB"
            "Total: $($summary.TotalSizeGB) GB"
            ''
            'Per system:'
            foreach ($row in $summary.PerSystem) { "$($row.System): $($row.Count) games, $($row.SizeGB) GB" }
            ''
            'Warnings:'
            foreach ($warning in @($summary.Warnings | Select-Object -First 100)) { "$($warning.System) - $($warning.CleanName): $($warning.IssuesText)" }
        ) -join [Environment]::NewLine
        Apply-Filters
        Add-Log 'Auto-selection applied.'
    } catch {
        Show-Error $_.Exception.Message
    }
})

$script:PreviewExportButton.Add_Click({ Start-Export -DryRun })
$script:RunExportButton.Add_Click({ Start-Export })
$script:CancelExportButton.Add_Click({ if ($script:ExportCts) { $script:ExportCts.Cancel(); Add-Log 'Export cancellation requested.' } })

$script:RunLibraryAutoActionButton.Add_Click({
    try {
        $action = Get-ComboContent $script:AutoActionCombo
        $value = Get-DoubleBox $script:AutoActionValueBox 0
        $items = @(ConvertTo-UiList $script:LibraryItems)
        Sync-SystemStateFromRows
        $excludedSystems = @($script:ExcludedSystems)
        $bestDuplicateOnly = [bool]$script:AutoBestDuplicateOnlyCheck.IsChecked
        $allowCrossSystemDuplicates = [bool]$script:AllowDuplicatesAcrossSystemsCheck.IsChecked
        $beforeSelected = @($items | Where-Object { [bool](Get-UiProperty $_ 'Selected' $false) }).Count
        switch ($action) {
            'Top N overall' { $summary = Select-RomCuratorByCriteria -Items $items -TopNOverall ([int]$value) -ExcludeUnmatched -ExcludeSystems $excludedSystems -AutoSelectBestDuplicateOnly:$bestDuplicateOnly -AllowDuplicatesAcrossSystems:$allowCrossSystemDuplicates }
            'Top N per system' { $summary = Select-RomCuratorByCriteria -Items $items -TopNPerSystem ([int]$value) -ExcludeUnmatched -ExcludeSystems $excludedSystems -AutoSelectBestDuplicateOnly:$bestDuplicateOnly -AllowDuplicatesAcrossSystems:$allowCrossSystemDuplicates }
            'Score threshold' { $summary = Select-RomCuratorByCriteria -Items $items -MinimumScore ([int]$value) -ExcludeUnmatched -ExcludeSystems $excludedSystems -AutoSelectBestDuplicateOnly:$bestDuplicateOnly -AllowDuplicatesAcrossSystems:$allowCrossSystemDuplicates }
            'Fill size GB' { $summary = Select-RomCuratorByCriteria -Items $items -MaxTotalGB $value -ExcludeUnmatched -ExcludeSystems $excludedSystems -AutoSelectBestDuplicateOnly:$bestDuplicateOnly -AllowDuplicatesAcrossSystems:$allowCrossSystemDuplicates }
            'Best score per GB size GB' { $summary = Select-RomCuratorByCriteria -Items $items -MaxTotalGB $value -ExcludeUnmatched -FillMode BestScorePerGB -ExcludeSystems $excludedSystems -AutoSelectBestDuplicateOnly:$bestDuplicateOnly -AllowDuplicatesAcrossSystems:$allowCrossSystemDuplicates }
            default { $summary = Select-RomCuratorByCriteria -Items $items -MinimumScore 80 -ExcludeUnmatched -ExcludeSystems $excludedSystems -AutoSelectBestDuplicateOnly:$bestDuplicateOnly -AllowDuplicatesAcrossSystems:$allowCrossSystemDuplicates }
        }
        $script:LibraryGrid.Items.Refresh()
        Apply-Filters
        $script:AutoSelectInlineSummaryText.Text = "Selected now $($summary.CopyableSelectedCount) | skipped dupes $($summary.DuplicatesSkipped) | excluded systems $(@($excludedSystems).Count) | ROM $($summary.RomSizeGB) GB | media $($summary.MediaSizeGB) GB | warnings $(@($summary.Warnings).Count)"
        Add-Log "Library auto-select applied: $action value=$value beforeSelected=$beforeSelected selectedNow=$($summary.CopyableSelectedCount) totalSelected=$($summary.SelectedCount) totalGB=$($summary.TotalSizeGB) duplicateSkipped=$($summary.DuplicatesSkipped) excluded=$($excludedSystems -join ',') allowCrossSystemDuplicates=$allowCrossSystemDuplicates"
    } catch {
        Add-Log 'Library auto-select failed.' -Level 'ERROR' -Exception $_
        Show-Error $_.Exception.Message
    }
})

$script:Window.Add_Closing({
    Add-Log 'App closing.'
    if ($script:ScanCts) { $script:ScanCts.Cancel() }
    if ($script:ExportCts) { $script:ExportCts.Cancel() }
    try { if ($script:DiscoveryPowerShell) { $script:DiscoveryPowerShell.Stop() } } catch {}
    try { if ($script:CachePowerShell) { $script:CachePowerShell.Stop() } } catch {}
    Read-SettingsFromUi | Out-Null
    Save-RomCuratorSettings -Settings $script:Settings | Out-Null
})

[void]$script:Window.ShowDialog()
