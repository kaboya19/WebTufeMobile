import React, {useEffect} from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {StatusBar, Platform, View, Text, StyleSheet} from 'react-native';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';

import TufeHomePage from './pages/TufeHomePage';
import TufePage from './pages/TufePage';
import AnaGruplarPage from './pages/AnaGruplarPage';
import HarcamaGruplariPage from './pages/HarcamaGruplariPage';
import MaddelerPage from './pages/MaddelerPage';
import OzelGostergelerPage from './pages/OzelGostergelerPage';
import BultenlerPage from './pages/BultenlerPage';
import MetodolojiPage from './pages/MetodolojiPage';
import {GitHubCSVService} from './services/GitHubCSVService';

// Bakım modu - true olduğunda sadece bakım ekranı gösterilir
const MAINTENANCE_MODE = true;

const Tab = createBottomTabNavigator();

const MaintenanceScreen = () => {
  return (
    <View style={styles.container}>
      <Icon name="construction" size={80} color="#1976D2" />
      <Text style={styles.message}>
        Nihai veriler hazırlanıyor. Sabrınız için teşekkürler...
      </Text>
    </View>
  );
};

const App = () => {
  useEffect(() => {
    if (!MAINTENANCE_MODE) {
      checkAndClearCacheOnVersionChange();
    }
  }, []);

  const checkAndClearCacheOnVersionChange = async () => {
    try {
      const currentVersion = Constants.expoConfig?.version || '1.0.21';
      const buildNumber = Constants.expoConfig?.ios?.buildNumber || Constants.expoConfig?.android?.versionCode || '21';
      const fullVersion = `${currentVersion}+${buildNumber}`;

      const lastVersion = await AsyncStorage.getItem('last_app_version');

      // Versiyon değiştiyse cache'i temizle (ilk açılışta temizleme)
      if (lastVersion && lastVersion !== fullVersion) {
        console.log(`Versiyon güncellendi: ${lastVersion} -> ${fullVersion}, cache temizleniyor`);
        await GitHubCSVService.clearCache();
        await AsyncStorage.setItem('last_app_version', fullVersion);
      } else if (!lastVersion) {
        // İlk açılış - cache temizleme
        await AsyncStorage.setItem('last_app_version', fullVersion);
      }
    } catch (e) {
      console.log('Versiyon kontrolü hatası:', e);
    }
  };

  // Bakım modu aktifse sadece bakım ekranını göster
  if (MAINTENANCE_MODE) {
    return (
      <View style={styles.container}>
        <StatusBar
          barStyle={Platform.OS === 'ios' ? 'dark-content' : 'light-content'}
          backgroundColor="#fff"
        />
        <MaintenanceScreen />
      </View>
    );
  }

  return (
    <NavigationContainer>
      <StatusBar
        barStyle={Platform.OS === 'ios' ? 'dark-content' : 'light-content'}
        backgroundColor="#fff"
      />
      <Tab.Navigator
        screenOptions={{
          tabBarActiveTintColor: '#2196F3',
          tabBarInactiveTintColor: '#757575',
          headerStyle: {
            backgroundColor: '#fff',
          },
          headerTintColor: '#000',
          headerTitleStyle: {
            fontWeight: 'bold',
          },
        }}>
        <Tab.Screen
          name="AnaSayfa"
          component={TufeHomePage}
          options={{
            title: 'Ana Sayfa',
            tabBarIcon: ({color, size}) => (
              <Icon name="home" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="Tufe"
          component={TufePage}
          options={{
            title: 'TÜFE',
            tabBarIcon: ({color, size}) => (
              <Icon name="trending-up" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="AnaGruplar"
          component={AnaGruplarPage}
          options={{
            title: 'Ana Gruplar',
            tabBarIcon: ({color, size}) => (
              <Icon name="analytics" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="HarcamaGruplari"
          component={HarcamaGruplariPage}
          options={{
            title: 'Harcama Grupları',
            tabBarIcon: ({color, size}) => (
              <Icon name="shopping-cart" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="Maddeler"
          component={MaddelerPage}
          options={{
            title: 'Maddeler',
            tabBarIcon: ({color, size}) => (
              <Icon name="inventory" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="OzelGostergeler"
          component={OzelGostergelerPage}
          options={{
            title: 'Özel Göstergeler',
            tabBarIcon: ({color, size}) => (
              <Icon name="insights" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="Bultenler"
          component={BultenlerPage}
          options={{
            title: 'Bültenler',
            tabBarIcon: ({color, size}) => (
              <Icon name="article" size={size} color={color} />
            ),
          }}
        />
        <Tab.Screen
          name="Metodoloji"
          component={MetodolojiPage}
          options={{
            title: 'Metodoloji',
            tabBarIcon: ({color, size}) => (
              <Icon name="info" size={size} color={color} />
            ),
          }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  message: {
    fontSize: 24,
    fontWeight: '500',
    color: '#424242',
    textAlign: 'center',
    marginTop: 32,
    fontFamily: 'Roboto',
    letterSpacing: 0.5,
  },
});

export default App;

