[CmdletBinding()]param()
begin{
	clear
	$error.clear()
	#this initializes everything that can't be done via the new Powershell Classes
	. "$($PSScriptRoot)\init.ps1"
	
	#define main class
	Class CSTS{
		[String] $execPath;
		[HashTable]$controllers = @{};
		[HashTable]$objs = @{};
		[HashTable]$libs = @{};
		$timer = (New-Object System.Windows.Forms.Timer);
		$self;
		$db = "csts.dat";
		$role = (@('User','Admin')[ ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") ]);
		$ad = ""
		
		CSTS(){
			$this.execPath = $PSScriptRoot;
			$this.self = $this
		}
		
		[object] findName($name){
			return ( $global:csts.libs.gui.window.findName($name) )
		}
		
		[void] init(){
			if ((gwmi win32_computersystem).partofdomain -eq $true) {
				$global:csts.objs.add('AD', (Get-Object('ActiveDirectory')))
				$global:csts.objs.AD.buildAdTree()
				
				# should this be a deselected Item?
				$global:csts.findName('treeAD').add_MouseUp({
					
					if($this.selectedItem -eq $global:csts.ad){
					
						$item = ($global:csts.findName('treeAD').selectedItem)
						$item.IsSelected = $false
						
					}
					
					$global:csts.ad = $global:csts.findName('treeAD').selectedItem
				})
				
				# load next nodes on select
				$global:csts.findName('treeAD').add_SelectedItemChanged({
					if($this.selectedItem){
						$global:csts.objs.AD.loadLevel($this.selectedItem)
					}
				})
				
				# load next nodes on node expand
				$global:csts.findName('treeAD').items.add_Expanded({
					param($e, $s)
					$global:csts.objs.AD.loadLevel($s.originalSource)
				})
			}
	
			#load mine field select boxes in ribbon
			@(10,20,30,40,50) | % {
				$global:csts.findName('rGCatMineLength').Items.Add($_)
				$global:csts.findName('rGCatMines').Items.Add($_)
			}
			
			#load stig select boxes in ribbon
			ls "$($global:csts.execPath)\stigs\" -filter "*manual*" | ? { $_.name -notlike '*benchmark*' } | % {
				$global:csts.findName('rGCatSTIG').Items.Add($_)
			}
			
			ls "$($global:csts.execPath)\stigs" -filter "*benchmark*" | % {
				$global:csts.findName('rGCatSCAP').Items.Add($_)
			}
			
			#set up heart beat
			$this.timer.Interval = 1000
			$this.timer.Enabled = $true
			$this.timer.start() | out-null
			$this.timer.add_Tick( { $global:csts.Poll() } )
		}
					
		#this event will occur every second.
		[void] Poll(){
			#run through all the controllers poll methods
			$this.controllers.keys | %{
				if( ($this.controllers[$_] | gm | select -expand Name) -contains 'Poll' ){
					$this.controllers[$_].Poll()
				}
			}
			#this class has the pixel data stuff, so load it.
			$this.libs.gui.GetColors();
		}
		
		
		[void] Dispose(){
			$this.timer.stop()		
		}
	}
}
process{
	#create new CSTS object (global so all sub controllers can find it)
	$global:csts = [CSTS]::new()
	
	
	# load any libraries
	(gci "$($global:csts.execPath)\lib") | % { . "$($_.FullName)" }
	
	# load any object definitions
	(gci "$($global:csts.execPath)\obj") | % { . "$($_.FullName)" }
	
	# load all the controllers
	(gci "$($global:csts.execPath)\controllers") | % { 
		. "$($_.FullName)" | out-null
		$global:csts.controllers.add("$($_.BaseName)", (Get-Object("$($_.BaseName)")) ) | out-null
		$global:csts.controllers[$($_.BaseName)].registerEvents() | out-null
	}
	
	$global:csts.init() | out-null
	
	#this tests the sql installation
	# $test = [SQL]::Get( $global:csts.db ).query("SELECT name FROM sqlite_master WHERE type='table' AND name='test2'").execAssoc()
	# if($test -eq $null){
		# [SQL]::Get( $global:csts.db ).query("create table test2( id integer primary key, name text not null)").execNonQuery()
		# [SQL]::Get( $global:csts.db ).query("insert into test2(name) values ('test') ").execNonQuery()
	# }else{
		# [SQL]::Get( $global:csts.db ).query("insert into test2(name) values ('test') ").execNonQuery()
	# }

	# $global:csts.libs.SQL::Get( $global:csts.db ).query("SELECT * FROM test2").execAssoc().ForEach({[PSCustomObject]$_}) | Format-Table -AutoSize

	#show the form.  This is a dialog, so after this all actions must be event calls or based off the heart beat.
	$global:csts.libs.GUI.ShowContent("/views/home.xaml") | out-null
	$global:csts.libs.GUI.ShowDialog() | out-null
}
end{
	$global:csts.libs.SQL::Get( $global:csts.db ).Close() | out-null
	$global:csts.Dispose();
	[System.GC]::Collect() | out-null
	$error;
}